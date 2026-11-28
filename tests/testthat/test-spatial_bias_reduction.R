skip_if_not_installed("terra")
skip_if_not_installed("sf")
skip_if_not_installed("gstat")

crs <- "EPSG:3857"

# A grid of points carrying a stationary, spatially-autocorrelated residual field
# (a Gaussian random field with exponential covariance) so the variogram fits a
# real range and kriging has structure to interpolate.
make_points <- function(step = 100, rng = 250, psill = 1, nugget = 0.02, seed = 1) {
  g <- expand.grid(x = seq(0, 900, by = step), y = seq(0, 900, by = step))
  d <- as.matrix(stats::dist(g))
  sigma <- psill * exp(-d / rng) + diag(nugget, nrow(g))
  set.seed(seed)
  g$resid <- as.numeric(t(chol(sigma)) %*% stats::rnorm(nrow(g)))
  sf::st_as_sf(g, coords = c("x", "y"), crs = crs)
}

# A dense grid of spatially-independent noise: reliably a pure-nugget variogram.
make_noise <- function(step = 50, seed = 1) {
  g <- expand.grid(x = seq(0, 900, by = step), y = seq(0, 900, by = step))
  set.seed(seed)
  g$resid <- stats::rnorm(nrow(g))
  sf::st_as_sf(g, coords = c("x", "y"), crs = crs)
}

# A coarse raster template to krige onto / correct.
make_template <- function(res = 150) {
  r <- terra::rast(terra::ext(0, 900, 0, 900), resolution = res, crs = crs)
  terra::values(r) <- 0.5
  names(r) <- "suitability"
  r
}

# A dissimilarity-index AOA surface: in-AOA (low DI) on the left half only.
make_di <- function(res = 150, thresh_in = 0.5, thresh_out = 2) {
  r <- terra::rast(terra::ext(0, 900, 0, 900), resolution = res, crs = crs)
  xy <- terra::crds(r)
  terra::values(r) <- ifelse(xy[, 1] < 450, thresh_in, thresh_out)
  names(r) <- "DI"
  r
}

# An AOA polygon covering the left half (x < 450).
make_poly <- function() {
  sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(450, 0), c(450, 900),
                             c(0, 900), c(0, 0)))),
    crs = crs
  ))
}

test_that("point_residuals attaches y - p and drops non-finite rows", {
  pts <- make_points()
  pts$obs <- c(1, rep(0, nrow(pts) - 1))
  pts$p   <- runif(nrow(pts))
  out <- point_residuals(pts, observed = "obs", predicted = "p")
  expect_true(all(c("pred", "resid") %in% names(out)))
  expect_equal(out$resid, out$obs - out$p)
  expect_true(all(is.finite(out$resid)))
})

test_that("point_residuals samples a raster `predicted` at the points", {
  pts <- make_points()
  pts$obs <- rbinom(nrow(pts), 1, 0.5)
  suit <- make_template()
  out <- point_residuals(pts, observed = "obs", predicted = suit)
  expect_equal(out$pred, rep(0.5, nrow(out)))
  expect_equal(out$resid, out$obs - 0.5)
})

test_that("residual_variogram flags pure nugget for noise, structure for a field", {
  vg <- residual_variogram(make_points())
  expect_named(vg, c("empirical", "model", "nugget", "psill", "range",
                     "nugget_ratio", "sample_var", "pure_nugget"))
  expect_false(vg$pure_nugget)
  expect_false(is.null(vg$model))

  expect_true(residual_variogram(make_noise())$pure_nugget)
})

test_that("restrict_to_aoa keeps DI <= thresh (points) and masks a raster", {
  pts <- make_points()
  di  <- make_di()
  kept <- restrict_to_aoa(pts, di, aoa_thresh = 1)
  xy <- sf::st_coordinates(kept)
  expect_true(all(xy[, 1] < 450))              # only the in-AOA (low DI) left half
  expect_lt(nrow(kept), nrow(pts))

  tmpl <- make_template()
  masked <- restrict_to_aoa(tmpl, di, aoa_thresh = 1)
  mx <- terra::crds(masked, na.rm = TRUE)
  expect_true(all(mx[, 1] < 450))
})

test_that("residual_krige returns a two-layer correction raster", {
  pts <- make_points()
  vg  <- residual_variogram(pts)
  out <- residual_krige(pts, make_template(), model = vg$model)
  expect_s4_class(out, "SpatRaster")
  expect_equal(names(out), c("correction", "krige_var"))
  expect_false(all(is.na(terra::values(out[["correction"]]))))
})

test_that("residual_krige errors on a NULL (pure-nugget) model", {
  pts <- make_points()
  expect_error(residual_krige(pts, make_template(), model = NULL), "nothing to interpolate")
})

test_that("residual_krige confines the correction to the AOA", {
  pts <- make_points()
  vg  <- residual_variogram(pts)
  out <- residual_krige(pts, make_template(), model = vg$model,
                        aoa = make_di(), aoa_thresh = 1)
  cor_xy <- terra::crds(out[["correction"]], na.rm = TRUE)
  expect_true(all(cor_xy[, 1] < 450))          # nothing predicted outside the AOA
})

test_that("bootstrap_correction returns mean/sd and is seed-reproducible (serial)", {
  pts <- make_points()
  vg  <- residual_variogram(pts)
  b1 <- bootstrap_correction(pts, make_template(), model = vg$model, n = 20,
                             seed = 42, cores = 1)
  b2 <- bootstrap_correction(pts, make_template(), model = vg$model, n = 20,
                             seed = 42, cores = 1)
  expect_equal(names(b1), c("corr_mean", "corr_sd"))
  expect_equal(terra::values(b1), terra::values(b2))
  expect_true(all(terra::values(b1[["corr_sd"]], na.rm = TRUE) >= 0))
})

test_that("apply_residual_correction adds the surface and clamps to range", {
  pred <- make_template()
  corr <- make_template(); terra::values(corr) <- 1       # push above 1
  out <- apply_residual_correction(pred, corr, clamp = c(0, 1))
  expect_equal(names(out), "suitability_corrected")
  expect_true(max(terra::values(out), na.rm = TRUE) <= 1)
  expect_equal(unique(terra::values(out))[1], 1)          # 0.5 + 1 clamped to 1
})

test_that("apply_residual_correction keeps or blanks cells outside the AOA", {
  pred <- make_template()
  corr <- make_template(); terra::values(corr) <- 0.2
  corr[1] <- NA                                           # a cell with no correction
  keep <- apply_residual_correction(pred, corr, outside = "keep")
  na   <- apply_residual_correction(pred, corr, outside = "na")
  expect_equal(terra::values(keep)[1], 0.5, ignore_attr = TRUE)   # uncorrected
  expect_true(is.na(terra::values(na)[1]))
})

test_that("reduce_spatial_bias runs end to end and corrects within range", {
  pts <- make_points()
  res <- reduce_spatial_bias(pts, make_template(), aoa = make_di(), aoa_thresh = 1)
  expect_named(res, c("corrected", "correction", "variogram"))
  expect_s4_class(res$corrected, "SpatRaster")
  vals <- terra::values(res$corrected, na.rm = TRUE)
  expect_true(all(vals >= 0 & vals <= 1))
})

test_that("reduce_spatial_bias short-circuits a pure-nugget field", {
  tmpl <- make_template()
  expect_warning(res <- reduce_spatial_bias(make_noise(), tmpl), "pure nugget")
  expect_null(res$correction)
  expect_equal(terra::values(res$corrected), terra::values(tmpl))  # pred unchanged
})

# ---- edge cases and the non-raster / polygon paths ------------------------

test_that("point_residuals validates inputs", {
  pts <- make_points()
  pts$obs <- rbinom(nrow(pts), 1, 0.5)
  expect_error(point_residuals(pts, observed = "nope", predicted = "obs"),
               "not found")
  # numeric-vector `predicted`
  out <- point_residuals(pts, observed = "obs", predicted = rep(0.3, nrow(pts)))
  expect_equal(out$pred, rep(0.3, nrow(out)))
  # length mismatch
  expect_error(point_residuals(pts, observed = "obs", predicted = c(0.1, 0.2)),
               "lengths differ")
})

test_that("residual_variogram honours cutoff and width", {
  pts <- make_points()
  vg <- residual_variogram(pts, cutoff = 600, width = 60)
  expect_true(max(vg$empirical$dist) <= 600)
})

test_that("restrict_to_aoa supports polygon and SpatVector AOAs", {
  pts <- make_points()
  poly <- make_poly()
  kept <- restrict_to_aoa(pts, poly)
  expect_true(all(sf::st_coordinates(kept)[, 1] < 450))
  # SpatVector polygon, points
  keptv <- restrict_to_aoa(pts, terra::vect(poly))
  expect_equal(nrow(keptv), nrow(kept))
  # polygon masking of a raster
  masked <- restrict_to_aoa(make_template(), poly)
  expect_true(all(terra::crds(masked, na.rm = TRUE)[, 1] < 450))
})

test_that("restrict_to_aoa resamples a DI surface of mismatched geometry", {
  masked <- restrict_to_aoa(make_template(res = 150), make_di(res = 100),
                            aoa_thresh = 1)
  expect_true(all(terra::crds(masked, na.rm = TRUE)[, 1] < 450))
})

test_that("residual_krige predicts onto sf points (non-raster newdata)", {
  pts <- make_points()
  vg  <- residual_variogram(pts)
  nd  <- make_points(step = 300, seed = 9)[, 0]      # bare point locations
  k <- residual_krige(pts, nd, model = vg$model)
  expect_s3_class(k, "sf")
  expect_true(all(c("var1.pred", "var1.var") %in% names(k)))
})

test_that("bootstrap_correction errors on a NULL model", {
  expect_error(
    bootstrap_correction(make_points(), make_template(), model = NULL, n = 5),
    "nothing to interpolate"
  )
})

test_that("bootstrap_correction returns point columns for sf newdata", {
  pts <- make_points()
  vg  <- residual_variogram(pts)
  nd  <- make_points(step = 300, seed = 9)[, 0]
  b <- bootstrap_correction(pts, nd, model = vg$model, n = 10, seed = 1, cores = 1)
  expect_s3_class(b, "sf")
  expect_true(all(c("corr_mean", "corr_sd") %in% names(b)))
})

test_that("bootstrap_correction runs on multiple cores", {
  skip_on_os("windows")
  pts <- make_points()
  vg  <- residual_variogram(pts)
  b <- bootstrap_correction(pts, make_template(), model = vg$model, n = 8,
                            seed = 5, cores = 2)
  expect_equal(names(b), c("corr_mean", "corr_sd"))
})

test_that("bootstrap_correction yields NA where every kriging draw fails", {
  # jitter = 0 leaves duplicate resampled locations, so each kriging system is
  # singular and fails; the draw falls back to all-NA.
  pts <- make_points()
  vg  <- residual_variogram(pts)
  b <- bootstrap_correction(pts, make_template(), model = vg$model, n = 5,
                            jitter = 0, seed = 1, cores = 1)
  expect_true(all(is.na(terra::values(b[["corr_mean"]]))))
})

test_that("apply_residual_correction resamples a mismatched correction grid", {
  pred <- make_template(res = 150)
  corr <- make_template(res = 100); terra::values(corr) <- 0.1
  out <- apply_residual_correction(pred, corr)
  expect_true(terra::compareGeom(out, pred, stopOnError = FALSE))
  expect_equal(names(out), "suitability_corrected")
})

test_that("reduce_spatial_bias runs the bootstrap branch", {
  pts <- make_points()
  res <- reduce_spatial_bias(pts, make_template(), bootstrap = TRUE, n = 8,
                             seed = 1, cores = 1)
  expect_equal(names(res$correction), c("corr_mean", "corr_sd"))
  expect_s4_class(res$corrected, "SpatRaster")
})

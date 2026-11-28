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

skip_if_not_installed("terra")

tmpl <- function() {
  r <- terra::rast(terra::ext(0, 1000, 0, 1000), resolution = 50, crs = "EPSG:3857")
  terra::values(r) <- 0
  r
}

test_that("geo_distance rescales to [0,1] and inverts to near = high", {
  r <- tmpl()
  src <- terra::vect(matrix(c(25, 25), ncol = 2), crs = "EPSG:3857")
  d  <- geo_distance(src, r)
  di <- geo_distance(src, r, invert = TRUE)
  expect_s4_class(d, "SpatRaster")
  expect_equal(terra::nlyr(d), 1L)
  expect_equal(terra::global(d, "min", na.rm = TRUE)[[1]], 0, tolerance = 1e-8)
  expect_equal(terra::global(d, "max", na.rm = TRUE)[[1]], 1, tolerance = 1e-8)
  # invert is the complement
  expect_equal(terra::global(di, "min", na.rm = TRUE)[[1]], 0, tolerance = 1e-8)
  # cell nearest the source: low raw distance, high inverted score
  near <- terra::extract(di, matrix(c(25, 25), ncol = 2))[[1]]
  far  <- terra::extract(di, matrix(c(975, 975), ncol = 2))[[1]]
  expect_gt(near, far)
})

test_that("build_resistance is integer cost with a floor of 1", {
  base <- tmpl()
  hab  <- terra::setValues(terra::rast(base), seq_len(terra::ncell(base)) / terra::ncell(base))
  res  <- build_resistance(base, habitat = hab, w_habitat = 5)
  expect_s4_class(res, "SpatRaster")
  expect_true(terra::is.int(res))
  expect_gte(terra::global(res, "min", na.rm = TRUE)[[1]], 1)
})

test_that("tobler_friction is positive and named", {
  dem <- tmpl()
  terra::values(dem) <- as.numeric(seq_len(terra::ncell(dem)))
  fr <- tobler_friction(dem)
  expect_equal(names(fr), "friction")
  expect_gt(terra::global(fr, "min", na.rm = TRUE)[[1]], 0)
})

test_that("cost_distance accumulates from the source and inverts", {
  fr  <- terra::setValues(terra::rast(tmpl()), 1)   # uniform friction
  src <- terra::vect(matrix(c(500, 500), ncol = 2), crs = "EPSG:3857")
  cd  <- cost_distance(fr, src)
  expect_equal(terra::nlyr(cd), 1L)
  expect_equal(terra::global(cd, "min", na.rm = TRUE)[[1]], 0, tolerance = 1e-8)
  expect_lte(terra::global(cd, "max", na.rm = TRUE)[[1]], 1 + 1e-8)
  # source cell is the cheapest (0); edges are dearer
  at_src <- terra::extract(cd, matrix(c(500, 500), ncol = 2))[[1]]
  expect_equal(at_src, 0, tolerance = 1e-6)
})

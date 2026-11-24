skip_if_not_installed("terra")
skip_if_not_installed("sf")

test_that("survey_weights drops sub-floor taxa and keeps w in (0, 1]", {
  set.seed(1)
  coords <- rbind(cbind(runif(20, 0, 1000), runif(20, 0, 1000)),  # A: 20 records
                  cbind(runif(3, 0, 1000),  runif(3, 0, 1000)))   # B: 3 records
  species <- c(rep("A", 20), rep("B", 3))
  w <- survey_weights(coords, species, min_records = 5)
  expect_equal(w$species, "A")                 # B is below the floor, dropped
  expect_true(all(w$w > 0 & w$w <= 1))
  expect_equal(w$n, 20)
})

test_that("guess_record_type flags plot programmes", {
  gt <- guess_record_type(c("FIA plots", "iNaturalist", "NEON veg survey", NA))
  expect_equal(gt, c("Plot", "Opportunistic", "Plot", NA))
})

test_that("eval_survey is high near records and zero beyond the kernel support", {
  set.seed(1)
  coords <- cbind(rnorm(6, 0, 10), rnorm(6, 0, 10))  # 6 records clustered at origin
  fld <- survey_field(coords, rep("A", 6), sigma = 50, min_records = 5)
  expect_s3_class(fld, "survey_field")
  s_near <- eval_survey(fld, matrix(c(0, 0), ncol = 2))
  s_far  <- eval_survey(fld, matrix(c(1e5, 1e5), ncol = 2))
  expect_gt(s_near, 0)
  expect_equal(s_far, 0)
  # restricting to an absent species recovers the empty (zero) layer
  expect_equal(eval_survey(fld, matrix(c(0, 0), ncol = 2), species = "Z"), 0)
})

test_that("survey_surface renders a [0,1] sparsity view end to end", {
  set.seed(1)
  coords <- cbind(rnorm(6, 500, 10), rnorm(6, 500, 10))
  tmpl <- terra::rast(terra::ext(0, 1000, 0, 1000), resolution = 50, crs = "EPSG:3857")
  srf <- survey_surface(coords, rep("A", 6), template = tmpl, sigma = 50,
                        min_records = 5, invert = TRUE)
  expect_s4_class(srf, "SpatRaster")
  expect_gte(terra::global(srf, "min", na.rm = TRUE)[[1]], 0)
  expect_lte(terra::global(srf, "max", na.rm = TRUE)[[1]], 1)
})

test_that("survey_raster: raw view is the field, rescale/invert give the sparsity surface", {
  set.seed(1)
  coords <- cbind(rnorm(6, 500, 10), rnorm(6, 500, 10))   # records clustered at (500, 500)
  fld <- survey_field(coords, rep("A", 6), sigma = 50, min_records = 5)
  tmpl <- terra::rast(terra::ext(0, 1000, 0, 1000), resolution = 50, crs = "EPSG:3857")

  # rescale = "none": the raw intensity field, non-negative, peaking at the records
  raw <- survey_raster(fld, template = tmpl, rescale = "none")
  expect_s4_class(raw, "SpatRaster")
  expect_equal(names(raw), "S")
  expect_gte(terra::global(raw, "min", na.rm = TRUE)[[1]], 0)
  expect_gt(terra::extract(raw, matrix(c(500, 500), ncol = 2))[[1]],   # hotspot
            terra::extract(raw, matrix(c(50, 50),  ncol = 2))[[1]])    # empty corner

  # quantile-rescaled + inverted: the [0,1] sparsity surface the index consumes,
  # LOW where the ground is well surveyed
  spars <- survey_raster(fld, template = tmpl, rescale = "quantile", invert = TRUE)
  expect_gte(terra::global(spars, "min", na.rm = TRUE)[[1]], 0)
  expect_lte(terra::global(spars, "max", na.rm = TRUE)[[1]], 1)
  expect_lt(terra::extract(spars, matrix(c(500, 500), ncol = 2))[[1]], # surveyed -> low
            terra::extract(spars, matrix(c(50, 50),  ncol = 2))[[1]])  # unsurveyed -> high
})

test_that("survey_raster builds from an extent and guards its arguments", {
  set.seed(1)
  coords <- cbind(rnorm(6, 500, 10), rnorm(6, 500, 10))
  fld <- survey_field(coords, rep("A", 6), sigma = 50, min_records = 5)
  ext <- terra::ext(0, 1000, 0, 1000)

  # an extent + res is an alternative to a template raster; two res = two views of one model
  expect_equal(terra::res(survey_raster(fld, template = ext, res = 100, rescale = "none"))[1], 100)
  expect_equal(terra::res(survey_raster(fld, template = ext, res = 50,  rescale = "none"))[1], 50)

  expect_error(survey_raster(fld, template = ext), "res")             # extent needs res
  expect_error(survey_raster(fld, template = ext, res = 50,           # no complement of an
                             rescale = "none", invert = TRUE), "invert")  #   unbounded field
})

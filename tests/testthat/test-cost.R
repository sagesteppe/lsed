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

test_that("build_resistance sums water, ruggedness and extra layers (floored, integer)", {
  base <- tmpl()
  mk01 <- function(frac) {                       # a binary 0/1 layer, `frac` of cells on
    r <- terra::rast(base); v <- rep(0, terra::ncell(r))
    v[seq_len(round(frac * terra::ncell(r)))] <- 1; terra::values(r) <- v; r
  }
  res <- build_resistance(
    base,
    oceans  = mk01(0.1), lakes = mk01(0.1), rivers = mk01(0.1),
    tri     = terra::setValues(terra::rast(base), as.numeric(seq_len(terra::ncell(base)))),
    habitat = terra::setValues(terra::rast(base), 0.5),
    addtl_r = c(terra::setValues(terra::rast(base), 1),
                terra::setValues(terra::rast(base), 2)),
    addtl_w = c(3, 4))
  expect_s4_class(res, "SpatRaster")
  expect_true(terra::is.int(res))
  expect_gte(terra::global(res, "min", na.rm = TRUE)[[1]], 1)      # floored at 1
  expect_gt(terra::global(res, "max", na.rm = TRUE)[[1]], 100)     # ocean-weighted cells
})

test_that("build_resistance accepts a precomputed surface and checks its geometry", {
  base <- tmpl()
  res  <- build_resistance(base, resistance_surface = terra::setValues(terra::rast(base), 7))
  expect_equal(terra::global(res, "max", na.rm = TRUE)[[1]], 7)    # builder args ignored
  bad  <- terra::rast(terra::ext(0, 500, 0, 500), resolution = 50, crs = "EPSG:3857")
  expect_error(build_resistance(base, resistance_surface = bad), "geometry")
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

# --- tiled cost distance + its clustering engine -------------------------------

test_that("cluster_region_extents returns one buffered extent per cluster", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(
    data.frame(x = c(90, 100, 110, 890, 900, 910),
               y = c(90, 110, 100, 910, 890, 900)),
    coords = c("x", "y"), crs = 3857)
  exts <- cluster_region_extents(pts, k = 2, buffer_m = 20, seed = 1)
  expect_length(exts, 2)
  expect_true(all(vapply(exts, inherits, logical(1), "SpatExtent")))

  inside <- function(e, px, py) {
    v <- as.vector(e); all(px >= v[1] & px <= v[2] & py >= v[3] & py <= v[4])
  }
  covers_lo <- vapply(exts, inside, logical(1), px = c(90, 100, 110), py = c(90, 110, 100))
  covers_hi <- vapply(exts, inside, logical(1), px = c(890, 900, 910), py = c(910, 890, 900))
  expect_equal(sum(covers_lo), 1L)   # the low cluster sits in exactly one extent
  expect_equal(sum(covers_hi), 1L)   # the high cluster in the other
})

test_that("cluster_region_extents bisects a cluster that exceeds max_cells", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(
    data.frame(x = c(0, 300, 600, 900, 100, 400, 700, 1000),
               y = c(0, 100, 200, 300, 50,  150, 250, 350)),
    coords = c("x", "y"), crs = 3857)
  whole <- cluster_region_extents(pts, k = 1, buffer_m = 0, seed = 1)  # no cap -> one leaf
  split <- cluster_region_extents(pts, k = 1, buffer_m = 0,            # extent too big -> split
                                  max_cells = 50, res_m = 50, seed = 1)
  expect_length(whole, 1)
  expect_gt(length(split), 1)
  expect_true(all(vapply(split, inherits, logical(1), "SpatExtent")))
})

test_that("cluster_region_extents requires res_m when max_cells is set", {
  skip_if_not_installed("sf")
  pts <- sf::st_as_sf(data.frame(x = c(0, 100), y = c(0, 100)),
                      coords = c("x", "y"), crs = 3857)
  expect_error(cluster_region_extents(pts, max_cells = 10, res_m = NULL), "res_m")
})

test_that("cost_distance tiles over source clusters and matches the untiled surface", {
  skip_if_not_installed("sf")
  fr  <- terra::setValues(terra::rast(tmpl()), 1)             # uniform friction
  # two source clusters (k = 2 needs >= 2 points per intended centre)
  src <- terra::vect(matrix(c(80, 80, 100, 100, 120, 120,
                             880, 880, 900, 900, 920, 920), ncol = 2, byrow = TRUE),
                     crs = "EPSG:3857")
  full  <- cost_distance(fr, src, tile = FALSE)
  tiled <- cost_distance(fr, src, tile = TRUE, k = 2, buffer_m = 3000)
  expect_s4_class(tiled, "SpatRaster")
  expect_equal(terra::nlyr(tiled), 1L)
  # source cell is the cheapest in the tiled surface too
  at_src <- terra::extract(tiled, matrix(c(100, 100), ncol = 2))[[1]]
  expect_equal(at_src, 0, tolerance = 1e-6)
  # buffer swamps the domain, so each tile covers it -> min-mosaic reproduces the whole
  d <- terra::values(tiled) - terra::values(full)
  expect_lt(max(abs(d), na.rm = TRUE), 1e-6)
})

skip_if_not_installed("terra")
skip_if_not_installed("sf")
skip_if_not_installed("igraph")

crs <- "EPSG:3857"

mk_patch <- function(x, y, s = 60) {
  sf::st_polygon(list(rbind(c(x, y), c(x + s, y), c(x + s, y + s),
                            c(x, y + s), c(x, y))))
}

make_inputs <- function() {
  suit <- terra::rast(terra::ext(0, 1000, 0, 1000), resolution = 50, crs = crs)
  set.seed(1); terra::values(suit) <- runif(terra::ncell(suit))
  patches <- sf::st_sf(
    acres = c(10, 20, 30, 40), prob_mean = c(0.2, 0.4, 0.6, 0.8),
    geometry = sf::st_sfc(mk_patch(100, 100), mk_patch(300, 300),
                          mk_patch(600, 600), mk_patch(800, 200), crs = crs))
  occ <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(150, 150)),
                                         sf::st_point(c(850, 850)), crs = crs))
  list(suit = suit, patches = patches, occ = occ)
}

test_that("cluster_patches groups nearby centroids into components", {
  inp <- make_inputs()
  cc <- cluster_patches(inp$patches, eps_km = 0.1)  # 100 m: all four separate
  expect_s3_class(cc, "sf")
  expect_true("cluster" %in% names(cc))
  expect_equal(nrow(cc), 4)
  expect_equal(length(unique(cc$cluster)), 4)
  # a huge eps merges everything into one cluster
  expect_equal(length(unique(cluster_patches(inp$patches, eps_km = 100)$cluster)), 1)
})

test_that("rank_calculate assembles the offline terms (Dg, Dr, P) and ranks", {
  inp <- make_inputs()
  res <- rank_calculate(inp$patches, occ = inp$occ, suitability = inp$suit,
                        agg = 1, prob_col = "prob_mean")
  expect_s3_class(res, "sf")
  expect_equal(nrow(res), 4)
  # the three supplied terms plus the combined index and rank
  expect_true(all(c("Dg", "Dr", "P", "index", "rank") %in% names(res)))
  # no network/records -> A, C, S are absent
  expect_false(any(c("A", "C", "S") %in% names(res)))
  # rescaled terms are in [0, 1]; rank is a 1..n permutation
  expect_true(all(res$index >= 0 & res$index <= 1, na.rm = TRUE))
  expect_setequal(res$rank, 1:4)
})

test_that("rank_calculate adds the S term when records are supplied", {
  inp <- make_inputs()
  set.seed(2)
  rec <- sf::st_sf(
    speciesKey = rep(1L, 6), basisOfRecord = rep("PRESERVED_SPECIMEN", 6),
    geometry = sf::st_sfc(lapply(seq_len(6), function(i)
      sf::st_point(c(200 + rnorm(1, 0, 20), 200 + rnorm(1, 0, 20)))), crs = crs))
  res <- rank_calculate(inp$patches, occ = inp$occ, suitability = inp$suit,
                        records = rec, agg = 1, sigma = 100, prob_col = "prob_mean")
  expect_true("S" %in% names(res))
  expect_equal(nrow(res), 4)
})

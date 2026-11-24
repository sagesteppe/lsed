skip_if_not_installed("sf")

# Pure helpers extracted from the network-bound download functions, so the parsing,
# filtering and bbox-coercion branches are testable without hitting GBIF / Overpass.

# --- .osm_ways_to_sf: Overpass JSON -> sf -------------------------------------

test_that(".osm_ways_to_sf parses ways and classes highways road/trail/NA", {
  j <- list(
    osm3s = list(timestamp_osm_base = "2024-01-01T00:00:00Z"),
    elements = list(
      list(type = "way", id = 1, tags = list(highway = "primary"),
           geometry = list(list(lon = 0, lat = 0), list(lon = 1, lat = 0))),
      list(type = "way", id = 2, tags = list(highway = "path"),
           geometry = list(list(lon = 0, lat = 1), list(lon = 1, lat = 1))),
      list(type = "way", id = 3, tags = list(highway = "pedestrian"),  # neither set
           geometry = list(list(lon = 0, lat = 2), list(lon = 1, lat = 2))),
      list(type = "node", id = 99)))                                   # dropped (no geom)

  out <- lsed:::.osm_ways_to_sf(j, roads = "primary", trails = "path")
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 3L)                               # the node is filtered out
  expect_type(out$osm_id, "character")
  expect_equal(out$class, c("road", "trail", NA))           # classed against the sets
  expect_equal(unique(as.character(sf::st_geometry_type(out))), "LINESTRING")
  expect_equal(sf::st_crs(out), sf::st_crs(4326))
  expect_equal(attr(out, "timestamp"), "2024-01-01T00:00:00Z")
})

test_that(".osm_ways_to_sf returns the canonical empty sf when no ways come back", {
  j <- list(osm3s = list(timestamp_osm_base = "t0"), elements = list())
  out <- lsed:::.osm_ways_to_sf(j, roads = "primary", trails = "path")
  expect_equal(nrow(out), 0L)
  expect_equal(names(out), c("osm_id", "highway", "class", "geometry"))
  expect_equal(attr(out, "timestamp"), "t0")
})

# --- .gbif_occ_to_sf: occurrence frame -> sf ----------------------------------

test_that(".gbif_occ_to_sf drops incomplete rows and keeps the standard columns", {
  occ <- data.frame(
    decimalLongitude = c(10, 20, NA, 30),   # row 3 has no lon
    decimalLatitude  = c(40, 50, 60, NA),   # row 4 has no lat
    speciesKey       = c(1, NA, 3, 4),      # row 2 has no speciesKey
    species          = c("a", "b", "c", "d"),
    basisOfRecord    = c("W", "X", "Y", "Z"),
    year             = c(2000, 2001, 2002, 2003),
    stringsAsFactors = FALSE)

  out <- lsed:::.gbif_occ_to_sf(occ, sf::st_crs(4326))
  expect_s3_class(out, "sf")
  expect_equal(nrow(out), 1L)                               # only row 1 is complete
  expect_equal(out$speciesKey, 1)
  expect_true(all(c("speciesKey", "species", "basisOfRecord", "year") %in% names(out)))
  expect_equal(sf::st_crs(out), sf::st_crs(4326))
})

test_that(".gbif_occ_to_sf tolerates missing optional columns and reprojects", {
  occ <- data.frame(decimalLongitude = c(10, 20), decimalLatitude = c(40, 50),
                    speciesKey = c(1, 2))                   # no species/basis/year
  out <- lsed:::.gbif_occ_to_sf(occ, sf::st_crs(3857))
  expect_equal(nrow(out), 2L)
  expect_equal(setdiff(names(out), "geometry"), "speciesKey")  # only what was present
  expect_equal(sf::st_crs(out)$epsg, 3857L)                 # transformed off 4326
})

# --- .lonlat_bbox: coerce various inputs to a lon/lat box ---------------------

test_that(".lonlat_bbox passes a numeric box through with an unknown CRS", {
  b <- lsed:::.lonlat_bbox(c(0, 0, 1, 1))
  expect_equal(b$box, c(0, 0, 1, 1))
  expect_true(is.na(b$crs))
  expect_error(lsed:::.lonlat_bbox(c(0, 0, 1)))             # must be length 4
})

test_that(".lonlat_bbox reprojects an sf bbox to lon/lat and reports its source CRS", {
  pt <- sf::st_as_sf(sf::st_sfc(sf::st_point(c(500000, 4500000)),
                                sf::st_point(c(510000, 4510000)), crs = 32613))
  b <- lsed:::.lonlat_bbox(pt)
  expect_equal(b$crs, sf::st_crs(32613))                    # source CRS retained
  expect_true(all(b$box[c(1, 3)] > -110 & b$box[c(1, 3)] < -100))  # UTM 13N -> ~ -105 lon
  expect_true(all(b$box[c(2, 4)] > 40 & b$box[c(2, 4)] < 41))      # ~ 40.7 lat
})

test_that(".lonlat_bbox handles terra raster/vector/extent inputs", {
  skip_if_not_installed("terra")
  # regression: terra::ext()[i] is named, which once mangled st_bbox's names -> all NA
  r <- terra::rast(terra::ext(0, 10, 0, 20), resolution = 1, crs = "EPSG:4326")
  expect_equal(lsed:::.lonlat_bbox(r)$box, c(0, 0, 10, 20))
  v <- terra::vect(matrix(c(0, 0, 10, 20), ncol = 2, byrow = TRUE), crs = "EPSG:4326")
  expect_equal(lsed:::.lonlat_bbox(v)$box, c(0, 0, 10, 20))
  # extent carries no CRS -> straight through (xmin,ymin,xmax,ymax)
  expect_equal(lsed:::.lonlat_bbox(terra::ext(1, 2, 3, 4))$box, c(1, 3, 2, 4))
})

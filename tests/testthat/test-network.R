skip_if_not_installed("igraph")

# A tiny hand-built patch graph lets us test complementarity()'s accounting and the
# cap_q clamp directly, without the sf/sfnetworks accessibility front end.
#   p1 - p2 - p3 - p4  (unit edges)   and   p4 --(100)-- p5   (one far outlier)
make_net <- function(long = 100) {
  e <- data.frame(
    from   = c("patch_1", "patch_2", "patch_3", "patch_4"),
    to     = c("patch_2", "patch_3", "patch_4", "patch_5"),
    weight = c(1, 1, 1, long)
  )
  list(graph = igraph::graph_from_data_frame(e, directed = FALSE))
}

test_that("complementarity assembly cost is the travel to gather target_area", {
  pn <- paste0("patch_", 1:5)
  # each patch is 30 acres, target 50 -> must reach exactly one neighbour
  res <- complementarity(make_net(), pn, areas = rep(30, 5),
                         target_area = 50, cap_q = NULL)
  expect_equal(res$patch_node, pn)
  # p1..p4 each have a unit-distance neighbour; p5's nearest is p4 at 100
  expect_equal(res$assemble_hr, c(1, 1, 1, 1, 100))
  expect_true(all(res$C >= 0 & res$C <= 1))
})

test_that("cap_q clamps the right tail before rescaling", {
  pn <- paste0("patch_", 1:5)
  res <- complementarity(make_net(), pn, areas = rep(30, 5),
                         target_area = 50, cap_q = 0.8)
  cap <- stats::quantile(c(1, 1, 1, 1, 100), 0.8, names = FALSE)
  expect_equal(max(res$assemble_hr), cap)      # outlier pulled down to the quantile
  expect_equal(res$assemble_hr[5], cap)
  expect_equal(res$assemble_hr[1:4], c(1, 1, 1, 1))  # below-cap costs untouched
})

test_that("unreachable patches: capped to a finite worst value, else max finite", {
  pn <- paste0("patch_", 1:5)
  # disconnect p5 entirely -> it can never gather target_area (Inf)
  g <- igraph::graph_from_data_frame(
    data.frame(from = c("patch_1", "patch_2", "patch_3"),
               to   = c("patch_2", "patch_3", "patch_4"),
               weight = c(1, 1, 1)),
    directed = FALSE,
    vertices = data.frame(name = pn))
  net <- list(graph = g)

  # no cap: Inf falls back to the worst finite cost (1 here)
  nocap <- complementarity(net, pn, areas = rep(30, 5),
                           target_area = 50, cap_q = NULL)
  expect_true(all(is.finite(nocap$assemble_hr)))
  expect_equal(nocap$assemble_hr[5], max(nocap$assemble_hr[1:4]))

  # with cap: Inf is clamped to the quantile too (all costs equal here -> constant)
  capped <- complementarity(net, pn, areas = rep(30, 5), target_area = 50, cap_q = 0.95)
  expect_true(all(is.finite(capped$assemble_hr)))
})

test_that("cap_q is validated", {
  pn <- paste0("patch_", 1:5)
  expect_error(complementarity(make_net(), pn, areas = rep(30, 5), cap_q = 1.5))
  expect_error(complementarity(make_net(), pn, areas = rep(30, 5), cap_q = 0))
  # areas length must match patch_nodes
  expect_error(complementarity(make_net(), pn, areas = rep(30, 4)))
})

# ---------------------------------------------------------------------------
# The sf/sfnetworks front end: build_network() + accessibility() (+ osm_speeds).
# A minimal projected road+trail network (metres, UTM 13N):
#   road  (0,0)--(1000,0)        highway "primary" -> osm_speeds 70 km/h
#   trail (1000,0)--(1000,1000)  highway "track"   -> osm_speeds 15 km/h
# the two share the junction (1000,0), so a correct noding gives 3 nodes.
# ---------------------------------------------------------------------------
make_lines <- function() {
  rd <- sf::st_linestring(matrix(c(0, 0, 1000, 0), ncol = 2, byrow = TRUE))
  tr <- sf::st_linestring(matrix(c(1000, 0, 1000, 1000), ncol = 2, byrow = TRUE))
  sf::st_sf(class    = c("road", "trail"),
            highway  = c("primary", "track"),
            geometry = sf::st_sfc(rd, tr, crs = 32613))
}

test_that("build_network nodes junctions and times edges by osm_speeds", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")

  net <- build_network(make_lines())
  expect_named(net, c("graph", "nodes", "edges"))
  expect_s3_class(net$graph, "igraph")
  expect_false(igraph::is_directed(net$graph))
  expect_equal(nrow(net$nodes), 3)              # the shared (1000,0) junction is one node
  expect_equal(igraph::gorder(net$graph), 3)

  ed <- net$edges
  expect_setequal(ed$class, c("road", "trail"))
  rd <- ed[ed$class == "road", ]
  tr <- ed[ed$class == "trail", ]
  # speed comes from osm_speeds[highway], not the class fallback (road 30 / trail 4)
  expect_equal(rd$speed, unname(osm_speeds["primary"]))   # 70, not 30
  expect_equal(tr$speed, unname(osm_speeds["track"]))     # 15, not 4
  # edge weight is hours = length_km / speed
  expect_equal(rd$weight, (rd$len / 1000) / rd$speed)
  expect_equal(tr$weight, (tr$len / 1000) / tr$speed)
})

test_that("build_network falls back to class speed for an unlisted highway", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")

  ln <- make_lines()
  ln$highway <- c("primary", "not_a_real_tag")    # trail highway absent from osm_speeds
  net <- build_network(ln, trail_speed = 4)
  tr <- net$edges[net$edges$class == "trail", ]
  expect_equal(tr$speed, 4)                        # class fallback, not NA
  expect_true(is.finite(tr$weight) && tr$weight > 0)
})

test_that("connect bridges a trailhead gap between stub ends of different classes", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")

  rd <- sf::st_linestring(matrix(c(0, 0, 1000, 0), ncol = 2, byrow = TRUE))
  tr <- sf::st_linestring(matrix(c(1030, 0, 1030, 1000), ncol = 2, byrow = TRUE)) # 30 m gap
  ln <- sf::st_sf(class = c("road", "trail"), highway = c("primary", "track"),
                  geometry = sf::st_sfc(rd, tr, crs = 32613))

  bridged <- build_network(ln, connect = 50)       # gap (30 m) <= connect
  split   <- build_network(ln, connect = 0)         # bridging disabled
  expect_true("connect" %in% igraph::E(bridged$graph)$class)
  expect_false("connect" %in% igraph::E(split$graph)$class)
  # the bridge joins trail to road into one reachable component
  expect_equal(igraph::components(bridged$graph)$no, 1L)
  expect_gt(igraph::components(split$graph)$no, 1L)
})

test_that("accessibility returns per-patch hours and an augmented graph", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")

  ln <- make_lines()
  patches <- sf::st_sf(
    id = c("road_side", "trail_end"),
    geometry = sf::st_sfc(sf::st_point(c(500, 10)),      # beside the road
                          sf::st_point(c(1000, 1010)),    # past the far trail end
                          crs = 32613))

  out <- accessibility(ln, patches)                 # origins = NULL -> road nodes are free
  expect_named(out, c("patches", "net", "patch_nodes"))
  expect_equal(out$patch_nodes, c("patch_1", "patch_2"))
  expect_true(all(c("access_hr", "A") %in% names(out$patches)))

  hr <- out$patches$access_hr
  expect_true(all(is.finite(hr)))
  expect_lt(hr[1], hr[2])                           # a short off-trail hop beats walking the trail
  # A is the inverted [0,1] score (default invert = TRUE): more accessible -> higher
  expect_true(all(out$patches$A >= 0 & out$patches$A <= 1))
  expect_gt(out$patches$A[1], out$patches$A[2])
  # patches become graph nodes so complementarity() can reuse the structure
  expect_true(all(out$patch_nodes %in% igraph::V(out$net$graph)$name))
})

test_that("contract_network collapses degree-2 runs but keeps class boundaries", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")
  skip_if_not_installed("tidygraph")

  # two collinear segments meeting at a degree-2 midpoint (500, 0)
  mk <- function(hw) sf::st_sf(
    highway  = hw, class = c("road", "road"),
    geometry = sf::st_sfc(
      sf::st_linestring(matrix(c(0, 0, 500, 0),    ncol = 2, byrow = TRUE)),
      sf::st_linestring(matrix(c(500, 0, 1000, 0), ncol = 2, byrow = TRUE)),
      crs = 32613))

  same <- suppressWarnings(contract_network(mk(c("primary", "primary"))))
  expect_s3_class(same, "sf")
  expect_equal(nrow(same), 1L)                         # degree-2 node smoothed away
  expect_equal(as.numeric(sum(sf::st_length(same))), 1000, tolerance = 1e-6) # length preserved
  expect_true("highway" %in% names(same))              # attributes carried through
  expect_false(any(c("from", "to") %in% names(same)))  # sfnetwork node indices dropped

  # require_equal = "highway" (default): a class change at the midpoint is not merged
  diff <- suppressWarnings(contract_network(mk(c("primary", "secondary"))))
  expect_equal(nrow(diff), 2L)
})

test_that("accessibility uses the DEM for the off-trail hop slope", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")
  skip_if_not_installed("terra")

  ln <- make_lines()
  patches <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(1000, 1010)), crs = 32613))
  flat <- accessibility(ln, patches)$patches$access_hr        # no dem -> flat-ground hop

  # a DEM whose elevation rises with y, so the off-trail hop climbs a real slope
  dem <- terra::rast(terra::ext(-100, 1100, -100, 1100), resolution = 50, crs = "EPSG:32613")
  terra::values(dem) <- terra::xyFromCell(dem, seq_len(terra::ncell(dem)))[, 2] * 0.5
  sloped <- accessibility(ln, patches, dem = dem)$patches$access_hr

  expect_true(is.finite(flat) && is.finite(sloped))
  expect_gt(sloped, flat)        # a steep off-trail hop costs more than the flat ideal
})

test_that("accessibility charges the drive from a remote origin", {
  skip_if_not_installed("sf")
  skip_if_not_installed("sfnetworks")

  ln <- make_lines()
  patches <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(1000, 1010)), crs = 32613))
  at_jct <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(1000, 0)), crs = 32613)) # trailhead
  far    <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 32613))     # 1 km up the road

  hr_near <- accessibility(ln, patches, origins = at_jct)$patches$access_hr
  hr_far  <- accessibility(ln, patches, origins = far)$patches$access_hr
  expect_true(is.finite(hr_near) && is.finite(hr_far))
  expect_gt(hr_far, hr_near)                         # the extra 1 km road drive adds time
})

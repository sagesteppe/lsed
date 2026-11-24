#' Accessibility (A) and complementarity (C) on a road/trail network graph
#'
#' A vector-first engine for the operational terms. Travel runs \strong{on the
#' linestrings} - roads and trails as a weighted \pkg{igraph}, each edge timed by its
#' class speed - and only the \strong{last hop} from the network to a patch centroid
#' drops to an off-trail Tobler cost. This sidesteps the resolution trap of a friction
#' raster (at 800 m a road is one fat cell) and, because the patches become graph
#' nodes, the same network answers \strong{C} (\code{\link{complementarity}}) for free.
#'
#' \strong{Model.} Roads are the drive-to origins (reachable at zero walking cost);
#' from there a crew walks trails (\code{trail_speed}) and finally cuts cross-country
#' to the centroid at a slope-dependent Tobler speed. Accessibility of a patch is the
#' least-cost path origin -> network -> hop, in hours.
#'
#' \strong{Noding.} OSM ways share vertex coordinates at junctions, so the graph is
#' built by snapping segment endpoints to a \code{snap}-metre grid - correct for OSM
#' topology. For arbitrary linework that crosses without shared vertices, pre-node it
#' (e.g. \code{sf::st_node}) before calling.
#'
#' @name network
NULL

#' Default per-\code{highway} travel speeds (km/h)
#'
#' Keyed on the OSM \code{highway} tag; an unlisted value falls back to the
#' road/trail class speed. Edit or pass your own to \code{\link{build_network}} /
#' \code{\link{accessibility}}. Drive classes are fast, foot classes ~walking.
#' @export
osm_speeds <- c(
  motorway = 90,
  trunk = 80,
  primary = 70,
  secondary = 55,
  tertiary = 45,
  unclassified = 35,
  residential = 30,
  service = 20,
  living_street = 15,
  track = 15,
  road = 30,
  path = 4,
  footway = 4,
  bridleway = 4,
  cycleway = 10,
  steps = 2
)

# ---------------------------------------------------------------------------
# Network construction
# ---------------------------------------------------------------------------

#' Contract an OSM network to junction-to-junction edges
#'
#' Collapses the raw OSM lines (every way vertex is a potential node, ~30x more than
#' needed) into one edge per junction-to-junction run, so the downstream graph is tiny
#' and every distance query is fast. Uses \pkg{sfnetworks}: subdivide at interior
#' junctions, then \code{to_spatial_smooth} drops degree-2 nodes - but only within a
#' single \code{require_equal} class, so motorway/primary/secondary/path boundaries
#' survive (and can carry different speeds later). Distance-preserving: a smoothed
#' edge's length is the sum of the run it replaces.
#'
#' @param lines road/trail \pkg{sf} lines with a \code{highway} (and \code{class})
#'   column, e.g. from \code{\link{osm_access}}.
#' @param require_equal edge attribute that must match for two edges to be smoothed
#'   together (default \code{"highway"} - never merge across road classes).
#' @return the contracted \pkg{sf} lines (one feature per junction-to-junction run),
#'   \code{highway}/\code{class} preserved - write this to disk and feed it to
#'   \code{\link{accessibility}}.
#' @export
contract_network <- function(lines, require_equal = "highway") {
  net <- sfnetworks::as_sfnetwork(lines, directed = FALSE)
  net <- tidygraph::convert(
    net,
    sfnetworks::to_spatial_subdivision,
    .clean = TRUE
  )
  net <- suppressWarnings(
    tidygraph::convert(
      net,
      sfnetworks::to_spatial_smooth,
      require_equal = require_equal,
      .clean = TRUE
    )
  )
  e <- sf::st_as_sf(net, "edges")
  e[, setdiff(names(e), c("from", "to")), drop = FALSE] # drop sfnetwork node indices
}

#' Build a travel-time graph from road/trail linestrings
#'
#' @param lines \pkg{sf} LINESTRINGs in a projected CRS (metres), with a \code{class}
#'   column ("road"/"trail"); \code{\link{osm_access}} output fits directly.
#' @param road_speed,trail_speed fallback class speeds in km/h (defaults 30, 4) for a
#'   \code{highway} tag not listed in \code{speeds}.
#' @param speeds named per-\code{highway} speed lookup in km/h (default
#'   \code{\link{osm_speeds}}); each contracted edge is single-\code{highway}, so one
#'   speed applies. Edge weight is \code{length / speed} - change \code{speeds} and
#'   rebuild (cheap) to re-time without re-pulling or re-contracting.
#' @param snap tight grid (metres) that segment endpoints snap to when forming nodes
#'   (default 1) - within-class noding, so parallel switchbacks/lanes are not fused.
#' @param connect liberal tolerance (metres, default 50) for bridging a \strong{stub
#'   end} of one class to the nearest node of the \emph{other} class - i.e. closing
#'   trailhead gaps where a trail dead-ends near a road (or a road near a trail)
#'   without a shared OSM node. Set \code{0} to disable. Only degree-1 ends are
#'   bridged, so it never fuses same-class features.
#' @return a list: \code{graph} (an undirected \pkg{igraph} with edge \code{weight} in
#'   hours and \code{class} - road/trail/connect, vertex coords \code{x}/\code{y}) and
#'   \code{nodes} (data.frame of node \code{name}, \code{x}, \code{y}).
#' @keywords internal
#' @export
build_network <- function(
  lines,
  road_speed = 30,
  trail_speed = 4,
  snap = 1,
  connect = 50,
  speeds = osm_speeds
) {
  lines <- sf::st_as_sf(lines)

  # Node via sfnetworks so junction topology is exact (shared endpoints, no
  # floating-point splits) - the input is a contracted, junction-to-junction network
  # (\code{\link{contract_network}} / \code{\link{osm_network_for}}).
  net <- sfnetworks::as_sfnetwork(lines, directed = FALSE)
  nsf <- sf::st_as_sf(net, "nodes")
  esf <- sf::st_as_sf(net, "edges")
  nc <- sf::st_coordinates(nsf)
  nodes <- data.frame(
    name = as.character(seq_len(nrow(nsf))),
    x = nc[, 1],
    y = nc[, 2],
    stringsAsFactors = FALSE
  )
  rownames(nodes) <- nodes$name

  cls <- if (!is.null(esf$class)) {
    as.character(esf$class)
  } else {
    rep("trail", nrow(esf))
  }
  hw <- if (!is.null(esf$highway)) {
    as.character(esf$highway)
  } else {
    rep(NA_character_, nrow(esf))
  }
  spd <- unname(speeds[hw]) # per-highway lookup
  fb <- ifelse(cls == "road", road_speed, trail_speed) # class fallback
  spd[is.na(spd)] <- fb[is.na(spd)]
  len <- as.numeric(sf::st_length(esf))
  edges <- data.frame(
    from = as.character(esf$from),
    to = as.character(esf$to),
    class = cls,
    highway = hw,
    len = len,
    speed = spd,
    weight = (len / 1000) / spd,
    stringsAsFactors = FALSE
  )
  edges$geometry <- sf::st_geometry(esf)
  edges <- edges[
    edges$from != edges$to & is.finite(edges$weight) & edges$weight > 0,
    ,
    drop = FALSE
  ]

  ge <- edges[, c("from", "to", "weight", "class")]

  # --- class-aware bridging of stub ends (trailhead gaps) ---
  if (connect > 0) {
    deg <- table(c(edges$from, edges$to))
    stubs <- names(deg)[deg == 1]
    road_nodes <- unique(c(
      edges$from[edges$class == "road"],
      edges$to[edges$class == "road"]
    ))
    trail_nodes <- unique(c(
      edges$from[edges$class == "trail"],
      edges$to[edges$class == "trail"]
    ))

    bridge <- function(src_cand, dst_names) {
      src <- intersect(stubs, src_cand)
      if (!length(src) || !length(dst_names)) {
        return(NULL)
      }
      s_sf <- sf::st_as_sf(
        nodes[src, ],
        coords = c("x", "y"),
        crs = sf::st_crs(lines)
      )
      d_sf <- sf::st_as_sf(
        nodes[dst_names, ],
        coords = c("x", "y"),
        crs = sf::st_crs(lines)
      )
      idx <- sf::st_nearest_feature(s_sf, d_sf)
      gap <- as.numeric(sf::st_distance(s_sf, d_sf[idx, ], by_element = TRUE))
      j <- dst_names[idx]
      keep <- gap <= connect & src != j
      if (!any(keep)) {
        return(NULL)
      }
      data.frame(
        from = src[keep],
        to = j[keep],
        weight = (gap[keep] / 1000) / trail_speed,
        class = "connect",
        stringsAsFactors = FALSE
      )
    }
    br <- rbind(
      bridge(trail_nodes, road_nodes),
      bridge(road_nodes, trail_nodes)
    )
    if (!is.null(br) && nrow(br)) {
      dk <- paste(pmin(br$from, br$to), pmax(br$from, br$to), sep = "|")
      ge <- rbind(ge, br[!duplicated(dk), , drop = FALSE])
    }
  }

  g <- igraph::graph_from_data_frame(ge, directed = FALSE, vertices = nodes)
  list(graph = g, nodes = nodes, edges = edges)
}

# ---------------------------------------------------------------------------
# Accessibility (A)
# ---------------------------------------------------------------------------

#' Accessibility of patches over the network (A)
#'
#' Finds the travel time from the \strong{origin} (field office / trailhead) to each
#' patch: drive the roads, walk the trails, then an off-trail Tobler hop to the
#' centroid. Each patch is joined to its \code{k} nearest \strong{origin-reachable}
#' nodes and takes the cheapest total route, so a patch beside an isolated trail
#' fragment bushwhacks to the usable network (a finite cost) instead of coming back
#' \code{NA}, and can enter via a connected trail it passes rather than a dead-end
#' stub. Returns the patches with a rescaled score \emph{and} the augmented graph (with
#' patches as nodes), so \code{\link{complementarity}} runs on the same structure.
#'
#' @param lines road/trail \pkg{sf} lines (see \code{\link{build_network}}).
#' @param patches \pkg{sf} points or polygons; polygons are reduced to centroids.
#' @param dem optional elevation \code{SpatRaster} (same CRS) for the Tobler hop slope;
#'   without it the hop uses \code{offtrail_speed} on the flat.
#' @param origins trip start as \pkg{sf} point(s) - typically the \strong{field
#'   office}, snapped free to the nearest road, after which road driving accrues time
#'   (often the dominant cost). \code{NULL} (default) treats every road node as a
#'   zero-cost origin ("distance from the road network", ignoring the drive).
#' @param k nearest origin-reachable nodes each patch may enter through (default
#'   \code{3}); the route uses whichever minimises drive/walk + hop.
#' @param road_speed,trail_speed,snap,connect,speeds passed to
#'   \code{\link{build_network}} (\code{speeds} is the per-\code{highway} km/h lookup,
#'   default \code{\link{osm_speeds}}; \code{connect} bridges trailhead gaps).
#' @param offtrail_speed unpenalised flat-ground off-trail speed in km/h when
#'   \code{dem} is absent (default \code{5}, ~Tobler on the level).
#' @param offtrail_penalty multiplier on the off-trail hop speed (default \code{0.5}):
#'   cross-country through brush/talus is slower than the slope-only Tobler ideal, so
#'   this keeps trails faster than bushwhacking. \code{1} removes the penalty.
#' @param invert if \code{TRUE} (default), the returned \code{A} is
#'   \eqn{1 - \tilde t} (accessible = high), the index form; raw hours are kept in
#'   \code{access_hr}.
#' @return a list: \code{patches} (input patches + \code{access_hr} and \code{A}),
#'   \code{net} (the augmented \code{build_network} list), and \code{patch_nodes} (the
#'   patch vertex names) for reuse by \code{\link{complementarity}}.
#' @export
accessibility <- function(
  lines,
  patches,
  dem = NULL,
  origins = NULL,
  k = 3,
  road_speed = 30,
  trail_speed = 4,
  snap = 1,
  connect = 50,
  speeds = osm_speeds,
  offtrail_speed = 5,
  offtrail_penalty = 0.5,
  invert = TRUE
) {
  net <- build_network(lines, road_speed, trail_speed, snap, connect, speeds)
  g <- net$graph
  nodes <- net$nodes
  node_pts <- sf::st_as_sf(nodes, coords = c("x", "y"), crs = sf::st_crs(lines))

  # origins: field-office points snapped to nearest ROAD node (free), else all roads.
  road_names <- unique(as.vector(igraph::ends(
    g,
    igraph::E(g)[igraph::E(g)$class == "road"],
    names = TRUE
  )))
  if (!length(road_names)) {
    road_names <- nodes$name
  } # no roads -> any node
  if (is.null(origins)) {
    onames <- road_names
  } else {
    origins <- sf::st_transform(origins, sf::st_crs(lines))
    road_pts <- sf::st_as_sf(
      nodes[road_names, ],
      coords = c("x", "y"),
      crs = sf::st_crs(lines)
    )
    onames <- unique(road_names[sf::st_nearest_feature(origins, road_pts)])
  }

  # Cost origin -> every network node once; the reachable set is the usable network.
  d0 <- apply(
    igraph::distances(g, v = onames, weights = igraph::E(g)$weight),
    2,
    min
  )
  reach <- names(d0)[is.finite(d0)]
  if (!length(reach)) {
    stop("no network nodes are reachable from the origin(s)")
  }
  reach_xy <- as.matrix(nodes[reach, c("x", "y")])

  # patch centroids
  patches <- sf::st_transform(patches, sf::st_crs(lines))
  cen <- if (all(sf::st_geometry_type(patches) %in% c("POINT", "MULTIPOINT"))) {
    sf::st_geometry(patches)
  } else {
    sf::st_centroid(sf::st_geometry(patches))
  }
  pc <- sf::st_coordinates(cen)[, 1:2, drop = FALSE]

  # Edge table from the network (exact sfnetworks node ids, no coordinate re-keying).
  edges <- net$edges
  egeo <- sf::st_sfc(edges$geometry, crs = sf::st_crs(lines))
  espd <- edges$speed # per-edge km/h

  # Usable edges: at least one endpoint reachable from the origin, non-degenerate.
  usable <- which(
    (edges$from %in% reach | edges$to %in% reach) & edges$from != edges$to
  )
  if (!length(usable)) {
    stop("no network edge is reachable from the origin(s)")
  }

  # Connect each patch to the nearest point on its nearest usable edge, then to that
  # edge's two endpoints by the along-edge offset - so the entry is the real nearest
  # point on a trail, not a distant junction (contraction must not cost us accuracy).
  nn <- usable[sf::st_nearest_feature(
    sf::st_as_sf(cen),
    sf::st_sf(geometry = egeo[usable])
  )]
  seg <- sf::st_nearest_points(cen, egeo[nn], by_element = TRUE) # patch -> proj
  hop_m <- as.numeric(sf::st_length(seg))
  proj <- sf::st_cast(seg, "POINT")[seq(2, 2 * length(nn), by = 2)]
  proj_xy <- sf::st_coordinates(proj)[, 1:2, drop = FALSE]
  offA <- vapply(
    seq_along(nn),
    function(i) {
      as.numeric(sf::st_line_project(egeo[nn[i]], proj[i]))
    },
    numeric(1)
  ) # metres A->proj
  offA <- pmin(pmax(offA, 0), edges$len[nn])
  offB <- edges$len[nn] - offA

  hop_hr <- hop_m /
    1000 /
    .hop_speed(pc, proj_xy, hop_m, dem, offtrail_speed, offtrail_penalty)
  wA <- hop_hr + (offA / 1000) / espd[nn] # patch -> endpoint A (hop + along-edge)
  wB <- hop_hr + (offB / 1000) / espd[nn]
  nA <- edges$from[nn]
  nB <- edges$to[nn]
  vn <- igraph::V(g)$name # endpoints that survived build_network
  okA <- nA %in% vn
  okB <- nB %in% vn
  dA <- d0[nA]
  dB <- d0[nB]
  dA[is.na(dA) | !okA] <- Inf
  dB[is.na(dB) | !okB] <- Inf
  acc <- pmin(dA + wA, dB + wB) # origin -> junction -> along -> hop
  acc[!is.finite(acc)] <- NA

  # Patches as nodes, each wired to its edge's (existing) endpoints for complementarity.
  pnames <- paste0("patch_", seq_len(nrow(pc)))
  g <- igraph::add_vertices(
    g,
    nrow(pc),
    name = pnames,
    x = pc[, 1],
    y = pc[, 2]
  )
  if (any(okA)) {
    g <- igraph::add_edges(
      g,
      as.vector(rbind(pnames[okA], nA[okA])),
      weight = wA[okA],
      class = "offtrail"
    )
  }
  if (any(okB)) {
    g <- igraph::add_edges(
      g,
      as.vector(rbind(pnames[okB], nB[okB])),
      weight = wB[okB],
      class = "offtrail"
    )
  }

  patches$access_hr <- acc
  patches$A <- .rescale01_vec(acc, invert)
  list(
    patches = patches,
    net = list(
      graph = g,
      nodes = rbind(nodes, data.frame(name = pnames, x = pc[, 1], y = pc[, 2]))
    ),
    patch_nodes = pnames
  )
}

# ---------------------------------------------------------------------------
# Complementarity (C)
# ---------------------------------------------------------------------------

#' Complementarity of patches: can a day's work be assembled nearby? (C)
#'
#' An isolation penalty, scaled by \strong{area} rather than count so a knot of
#' fragments does not out-rank a real patch. For each patch, walk outward over the
#' network (cheapest travel first) accumulating neighbouring patch \emph{acreage} until
#' a \code{target_area} day's worth is gathered; the travel cost that bundle required
#' is the isolation measure. A dense cluster assembles the target cheaply; a lone
#' fragment must range far (or cannot gather it at all). The score is flipped so
#' well-connected patches are high and isolated ones are penalised - no day-length
#' assumption, just the area target.
#'
#' Run on the augmented graph returned by \code{\link{accessibility}} (patches are
#' already nodes there). Distances are computed one source at a time, so memory stays
#' O(n) for large patch sets.
#'
#' @param net the \code{net} element from \code{\link{accessibility}} (its \code{graph}
#'   holds the patch nodes).
#' @param patch_nodes the \code{patch_nodes} from \code{\link{accessibility}}, aligned
#'   to \code{areas}.
#' @param areas numeric patch areas (acres), one per \code{patch_nodes} in order.
#' @param target_area a day's worth of patch area to assemble, in acres (default
#'   \code{50}; loose - the saturation scale, not a hard quota).
#' @param cap_q upper quantile (on \eqn{(0, 1]}) at which the raw assembly cost is
#'   clamped before rescaling (default \code{0.95}). The isolation cost has a long right
#'   tail - a lone fragment can range far, and unreachable patches are \code{Inf} - so a
#'   single outlier otherwise stretches the min-max rescale and flattens the gradient
#'   among the patches that actually differ. Costs above the \code{cap_q} quantile of the
#'   \emph{finite} costs (and every \code{Inf}) are set to that quantile: all such patches
#'   count as equally, maximally isolated. The cap is applied to \code{assemble_hr}
#'   itself, so it also carries through when the raw hours are rescaled downstream (e.g.
#'   by \code{\link{rank_index}} in \code{\link{rank_calculate}}). \code{NULL} disables
#'   the cap (then \code{Inf} falls back to the worst finite cost, as before).
#' @param cores fork workers for the per-patch distance loop (default \code{1}); the
#'   loop is the cost, so \code{cores} gives a near-linear speed-up (Unix only; falls
#'   back to serial on Windows).
#' @param invert if \code{TRUE} (default), return the flipped score \eqn{1 - \tilde c}
#'   (well-connected = high), the index form; raw assembly cost is kept in
#'   \code{assemble_hr}.
#' @return a data.frame with \code{patch_node}, \code{assemble_hr} (travel hours to
#'   gather \code{target_area}, clamped at the \code{cap_q} quantile; patches that never
#'   total it take that capped worst value) and \code{C} on \eqn{[0, 1]}, in
#'   \code{patch_nodes} order.
#' @seealso \code{\link{accessibility}}
#' @export
complementarity <- function(
  net,
  patch_nodes,
  areas,
  target_area = 50,
  cap_q = 0.95,
  cores = 1,
  invert = TRUE
) {
  stopifnot(
    length(areas) == length(patch_nodes),
    is.null(cap_q) || (length(cap_q) == 1L && cap_q > 0 && cap_q <= 1)
  )
  g <- net$graph
  w <- igraph::E(g)$weight
  n <- length(patch_nodes)

  # Reach to assemble target_area of nearest patches from patch i (self first).
  reach_one <- function(i) {
    d <- as.vector(igraph::distances(
      g,
      v = patch_nodes[i],
      to = patch_nodes,
      weights = w
    ))
    ord <- order(d)
    hit <- which(cumsum(areas[ord]) >= target_area)[1]
    if (is.na(hit)) Inf else d[ord[hit]]
  }
  # Embarrassingly parallel over patches; fork shares the graph copy-on-write.
  cost <- if (cores > 1) {
    unlist(
      parallel::mclapply(seq_len(n), reach_one, mc.cores = cores),
      use.names = FALSE
    )
  } else {
    vapply(seq_len(n), reach_one, numeric(1))
  }
  fin <- is.finite(cost)
  # Clamp the long right tail (and Inf) at the cap_q quantile of the finite costs, so one
  # far-ranging/unreachable patch cannot stretch the rescale and flatten everyone else.
  if (!is.null(cap_q) && any(fin)) {
    cap <- stats::quantile(cost[fin], cap_q, names = FALSE)
    cost[cost > cap] <- cap # finite outliers and Inf alike -> cap
    fin <- is.finite(cost) # Inf is now finite (== cap)
  }
  cost[!fin] <- if (any(fin)) max(cost[fin]) else 1 # no cap: Inf -> worst finite

  data.frame(
    patch_node = patch_nodes,
    assemble_hr = cost,
    C = .rescale01_vec(cost, invert),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# internal
# ---------------------------------------------------------------------------

# Off-trail Tobler speed (km/h) for each hop, times the off-trail penalty. With a DEM,
# slope = |dz| / run from the centroid to its network node; without, a flat
# offtrail_speed. The penalty makes bushwhacking slower than the slope-only ideal.
.hop_speed <- function(pc, node_xy, run, dem, offtrail_speed, penalty = 0.5) {
  if (is.null(dem) || !inherits(dem, "SpatRaster")) {
    return(rep(offtrail_speed * penalty, nrow(pc)))
  }
  z1 <- terra::extract(dem, pc)[, 1]
  z2 <- terra::extract(dem, as.matrix(node_xy))[, 1]
  S <- ifelse(run > 0, abs(z2 - z1) / run, 0)
  spd <- 6 * exp(-3.5 * abs(S + 0.05)) # Tobler km/h
  spd[!is.finite(spd) | spd <= 0] <- offtrail_speed
  spd * penalty
}

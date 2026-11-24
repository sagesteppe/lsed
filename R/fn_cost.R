#' Dispersal and accessibility terms (Dg, Dr, A) by isotropic cost distance
#'
#' The \code{RankIndex} distance terms, all on one terra-native, isotropic engine
#' (no \pkg{gdistance}/\pkg{raster}): a friction surface plus
#' \code{\link[terra]{costDist}} from a set of sources, tiled so large domains stay
#' in memory.
#'
#' \itemize{
#'   \item \strong{Dg} - geographic distance from a known population:
#'     \code{\link{geo_distance}} (straight-line \code{\link[terra]{distance}} to the
#'     nearest source).
#'   \item \strong{Dr} - resistance distance: \code{\link{build_resistance}} friction
#'     -> \code{\link{cost_distance}} from occupied populations.
#'   \item \strong{A} - accessibility: \code{\link{tobler_friction}} (walking cost) ->
#'     \code{\link{cost_distance}} from the road/trail network.
#' }
#'
#' All three return a surface rescaled to \eqn{[0, 1]}; because the index rewards
#' \emph{short} distance / \emph{easy} access, pass \code{invert = TRUE} for the
#' \eqn{1 - \tilde d} form the index consumes.
#'
#' \code{build_resistance()} is lifted from \pkg{safeHavens}
#' (\code{buildResistanceSurface}); the tiling (\code{\link{cluster_region_extents}},
#' mosaic-by-min) is lifted from the \code{Ecoloradense} cost-distance script. Both
#' are terra/sf only - the lift adds no dependency beyond \pkg{terra}, \pkg{sf}.
#'
#' @name cost
NULL

# ---------------------------------------------------------------------------
# Friction surfaces
# ---------------------------------------------------------------------------

#' Build an isotropic resistance (friction) surface
#'
#' Lifted from \pkg{safeHavens} \code{buildResistanceSurface()} (terra-only). Sums
#' weighted, optional layers - water features, terrain ruggedness, habitat and any
#' extras - into a per-cell cost of movement, clamped to a floor of 1 and stored as
#' integer. Feed the result to \code{\link{cost_distance}} for \strong{Dr}.
#'
#' @param base_raster \code{SpatRaster} giving template geometry/resolution.
#' @param resistance_surface optional precomputed resistance; if given, the builder
#'   arguments are ignored (geometry must match \code{base_raster}).
#' @param oceans,lakes,rivers binary (0/1) \code{SpatRaster}s of water features.
#' @param tri continuous terrain-ruggedness \code{SpatRaster} (z-scored internally).
#' @param habitat continuous \code{SpatRaster} whose \emph{high} values raise cost; for
#'   a dispersal surface pass inverted suitability (e.g. \code{1 - suitability}) so
#'   movement through good habitat is cheap.
#' @param w_ocean,w_lakes,w_rivers,w_tri,w_habitat weights applied to each layer.
#' @param addtl_r extra \code{SpatRaster} stack; \code{addtl_w} their weights (same
#'   length as \code{terra::nlyr(addtl_r)}).
#' @param addtl_w see \code{addtl_r}.
#' @return an integer \code{SpatRaster} of movement cost (minimum 1).
#' @export
build_resistance <- function(
  base_raster,
  resistance_surface = NULL,
  oceans = NULL,
  lakes = NULL,
  rivers = NULL,
  tri = NULL,
  habitat = NULL,
  w_ocean = 100,
  w_lakes = 50,
  w_rivers = 20,
  w_tri = 1,
  w_habitat = 1,
  addtl_r = NULL,
  addtl_w = NULL
) {
  if (!is.null(resistance_surface)) {
    res <- resistance_surface
    if (!terra::compareGeom(res, base_raster, stopOnError = FALSE)) {
      stop("resistance_surface must match base_raster geometry")
    }
  } else {
    res <- terra::rast(base_raster)
    terra::values(res) <- 0
    if (!is.null(oceans)) {
      res[oceans == 1] <- res[oceans == 1] + w_ocean
    }
    if (!is.null(lakes)) {
      res[lakes == 1] <- res[lakes == 1] + w_lakes
    }
    if (!is.null(rivers)) {
      res[rivers == 1] <- res[rivers == 1] + w_rivers
    }
    if (!is.null(tri)) {
      # NA-robust z-score (base scale() uses colMeans w/o na.rm, so a single NA
      # border cell would blank the whole layer).
      tv <- terra::values(tri)[, 1]
      z <- (tv - mean(tv, na.rm = TRUE)) / stats::sd(tv, na.rm = TRUE)
      res <- res + w_tri * terra::setValues(res, z)
    }
    if (!is.null(habitat)) {
      res <- res + w_habitat * habitat
    }
    if (!is.null(addtl_r) && terra::nlyr(addtl_r) == length(addtl_w)) {
      for (i in seq_along(addtl_w)) {
        res <- res + addtl_r[[i]] * addtl_w[i]
      }
    }
  }
  vals <- terra::values(res)
  if (!is.null(vals) && length(vals) > 0 && any(!is.na(vals))) {
    res <- terra::clamp(res, lower = 1L)
  }
  terra::as.int(res)
}

#' Tobler walking-cost friction for accessibility (A)
#'
#' An isotropic friction from Tobler's hiking function: walking speed
#' \eqn{W = 6\,e^{-3.5\,|S + 0.05|}} km/h on slope \eqn{S} (rise/run), so cost per
#' unit distance is \eqn{1/W}. Symmetric (uses \eqn{|S|}) - appropriate for access,
#' which is a round trip. Feed to \code{\link{cost_distance}} from roads/trails.
#'
#' @param dem elevation \code{SpatRaster} (projected, metres).
#' @return a \code{SpatRaster} of relative travel cost (higher = slower going).
#' @export
tobler_friction <- function(dem) {
  slope <- terra::terrain(dem, v = "slope", unit = "radians")
  S <- tan(slope)
  speed <- 6 * exp(-3.5 * abs(S + 0.05)) # km/h
  fric <- 1 / speed
  names(fric) <- "friction"
  fric
}

# ---------------------------------------------------------------------------
# Distance surfaces
# ---------------------------------------------------------------------------

#' Geographic distance from known populations (Dg)
#'
#' Straight-line distance to the nearest source, rescaled to \eqn{[0, 1]}.
#'
#' @param sources source features (\pkg{sf}/\code{SpatVector}; points, lines or polys).
#' @param template \code{SpatRaster} giving the output grid.
#' @param invert if \code{TRUE}, return \eqn{1 - \tilde d} (near = high), the index form.
#' @return a single-layer \code{SpatRaster} on \eqn{[0, 1]}.
#' @export
geo_distance <- function(sources, template, invert = FALSE) {
  d <- terra::distance(template, .as_vect(sources))
  .rescale01(d, invert)
}

#' Resistance / accessibility distance by isotropic cost distance (Dr, A)
#'
#' Accumulated least-cost distance from \code{sources} over a \code{friction} surface
#' (\code{\link[terra]{costDist}}), rescaled to \eqn{[0, 1]}. Sources are burned into
#' the friction as zero-cost targets. With \code{tile = TRUE} the work is split into
#' buffered regions around source clusters (\code{\link{cluster_region_extents}}) and
#' mosaicked by minimum cost, keeping large domains in memory; the buffer and the
#' min-mosaic absorb tile-edge effects.
#'
#' @param friction movement-cost \code{SpatRaster} (e.g. \code{\link{build_resistance}}
#'   or \code{\link{tobler_friction}}); values must be positive.
#' @param sources source features (\pkg{sf}/\code{SpatVector}): occupied populations
#'   for \strong{Dr}, the road/trail network for \strong{A}.
#' @param template output grid (defaults to \code{friction}).
#' @param tile split into buffered regions around source clusters (default
#'   \code{FALSE}).
#' @param k,buffer_m,max_cells,seed tiling controls, passed to
#'   \code{\link{cluster_region_extents}} (\code{res_m} is taken from \code{friction}).
#' @param invert if \code{TRUE}, return \eqn{1 - \tilde d} (near/accessible = high).
#' @return a single-layer \code{SpatRaster} on \eqn{[0, 1]}.
#' @export
cost_distance <- function(
  friction,
  sources,
  template = friction,
  tile = FALSE,
  k = 2,
  buffer_m = 3000,
  max_cells = NULL,
  seed = 1,
  invert = FALSE
) {
  src <- .as_vect(sources)

  if (!tile) {
    cd <- .costdist_tile(friction, src)
    return(.rescale01(terra::extend(cd, template), invert))
  }

  res_m <- terra::res(friction)[1]
  exts <- cluster_region_extents(
    sf::st_as_sf(src),
    k = k,
    buffer_m = buffer_m,
    max_cells = max_cells,
    res_m = res_m,
    seed = seed
  )
  tiles <- lapply(exts, function(e) {
    fr <- terra::crop(friction, e)
    s_in <- terra::crop(src, e)
    if (!nrow(s_in)) {
      return(NULL)
    }
    .costdist_tile(fr, s_in)
  })
  tiles <- Filter(Negate(is.null), tiles)
  merged <- if (length(tiles) > 1) {
    terra::mosaic(terra::sprc(tiles), fun = "min")
  } else {
    tiles[[1]]
  }
  .rescale01(terra::extend(merged, template), invert)
}

# ---------------------------------------------------------------------------
# internal
# ---------------------------------------------------------------------------

# Coerce to SpatVector only if not already one (sf / SpatVector both accepted).
.as_vect <- function(x) if (inherits(x, "SpatVector")) x else terra::vect(x)

# One costDist over a (possibly cropped) friction tile: burn sources in as the
# zero-cost target, then accumulate cost. Sources sit at value 0; the friction floor
# of 1 keeps 0 an unambiguous target sentinel.
.costdist_tile <- function(friction, src) {
  m <- terra::rasterize(src, friction)
  fr <- friction
  fr[!is.na(m)] <- 0
  terra::costDist(fr, target = 0)
}

# Min-max rescale to [0, 1], optionally complemented (1 - x).
.rescale01 <- function(r, invert = FALSE) {
  mn <- terra::global(r, "min", na.rm = TRUE)[[1]]
  mx <- terra::global(r, "max", na.rm = TRUE)[[1]]
  out <- if (is.finite(mx) && mx > mn) (r - mn) / (mx - mn) else r * 0
  if (invert) {
    out <- 1 - out
  }
  names(out) <- "d"
  out
}

#' Cluster sources into buffered, cell-capped regions for tiled cost distance
#'
#' Lifted from the \code{Ecoloradense} cost-distance script. Builds \code{k} kmeans
#' clusters of the source points, then recursively bisects any cluster whose
#' bounding-box+buffer exceeds \code{max_cells}; returns one \code{SpatExtent} per
#' leaf. \code{seed} fixes the kmeans so splits are reproducible.
#'
#' @param pts \pkg{sf} points.
#' @param k initial kmeans clusters.
#' @param buffer_m buffer (metres) added around each cluster's bbox.
#' @param max_cells cap on a leaf's cropped-extent cell count; \code{NULL} disables
#'   recursion (exactly \code{k} clusters).
#' @param res_m raster resolution (metres/cell); required when \code{max_cells} is set.
#' @param seed kmeans seed; \code{NULL} leaves the RNG untouched.
#' @return a list of \code{SpatExtent}.
#' @keywords internal
#' @export
cluster_region_extents <- function(
  pts,
  k = 2,
  buffer_m = 3000,
  max_cells = NULL,
  res_m = NULL,
  seed = 1
) {
  stopifnot(
    "res_m is required when max_cells is set" = is.null(max_cells) ||
      !is.null(res_m)
  )
  ext_of <- function(p) {
    sf::st_bbox(p) |>
      sf::st_as_sfc(crs = sf::st_crs(p)) |>
      sf::st_buffer(buffer_m) |>
      terra::vect() |>
      terra::ext()
  }
  ncell_of <- function(e) {
    v <- as.vector(e)
    ((v[2] - v[1]) / res_m) * ((v[4] - v[3]) / res_m)
  }
  kmeans_cluster <- function(p, centers) {
    if (!is.null(seed)) {
      set.seed(seed)
    }
    stats::kmeans(sf::st_coordinates(p), centers = centers)$cluster
  }
  split_recursive <- function(p) {
    e <- ext_of(p)
    if (is.null(max_cells) || nrow(p) < 4 || ncell_of(e) <= max_cells) {
      return(list(e))
    }
    cl <- kmeans_cluster(p, centers = 2)
    if (length(unique(cl)) < 2) {
      return(list(e))
    }
    do.call(
      c,
      lapply(sort(unique(cl)), function(i) split_recursive(p[cl == i, ]))
    )
  }
  cl0 <- kmeans_cluster(pts, centers = k)
  do.call(
    c,
    lapply(sort(unique(cl0)), function(i) split_recursive(pts[cl0 == i, ]))
  )
}

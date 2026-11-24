#' Score patches from the downloaded inputs (calculate module)
#'
#' The calculation half of the patch ranking: given the data acquired by
#' \code{\link{rank_download}} plus the on-disk surfaces, it computes every
#' \code{RankIndex} term, samples the raster terms at the patch centroids, and combines
#' them with \code{\link{rank_index}}. No network calls - it reads the files the
#' download module wrote, so it is fast to re-run while tuning weights.
#'
#' Terms are computed only when their inputs are supplied, so the ranking degrades
#' gracefully: omit \code{records} to drop \strong{S}, omit \code{network}/\code{origin}
#' to drop \strong{A}/\strong{C}. \strong{Dg}/\strong{Dr} need only \code{occ} and
#' \code{suitability}.
#'
#' @param patches \pkg{sf} units to score (polygons or points); must carry
#'   \code{area_col} for \strong{C}.
#' @param occ known-population points (\pkg{sf}/\code{SpatVector}) - the sources for
#'   \strong{Dg} and \strong{Dr}.
#' @param suitability habitat-suitability \code{SpatRaster} (or path): the template for
#'   the raster terms and, inverted, the dispersal resistance.
#' @param records GBIF \pkg{sf} with \code{speciesKey} (and \code{basisOfRecord}) for
#'   \strong{S}; \code{NULL} skips it.
#' @param network,origin OSM road/trail \pkg{sf} and the trip origin for \strong{A}/
#'   \strong{C}; \code{NULL} skips them.
#' @param dem optional elevation \code{SpatRaster} for the accessibility off-trail hop.
#' @param resistance optional precomputed friction \code{SpatRaster} for \strong{Dr};
#'   \code{NULL} builds one from inverted suitability (\code{\link{build_resistance}}).
#' @param agg integer factor to coarsen \code{suitability} by before the raster terms
#'   (default \code{10}); the ranking is sampled at centroids, so fine resolution is
#'   wasted here.
#' @param area_col patch-area column (acres) used by \strong{C} (default \code{"acres"}).
#' @param prob_col patch column holding the model suitability to enter as a term
#'   \code{P} (default \code{"prob_mean"}); a more-suitable patch is likelier real
#'   habitat. \code{NULL} omits it.
#' @param sigma,target_area,k,w_habitat,speeds term parameters passed through to
#'   \code{\link{survey_surface}} / \code{\link{complementarity}} /
#'   \code{\link{accessibility}} / \code{\link{build_resistance}}.
#' @param cores fork workers for \strong{C}'s per-patch distance loop (default
#'   \code{1}); passed to \code{\link{complementarity}}.
#' @param cap_q upper quantile at which \strong{C}'s raw assembly cost is clamped before
#'   the global rescale (default \code{0.95}; passed to \code{\link{complementarity}}).
#'   \code{NULL} disables the cap. See \code{\link{complementarity}} for why the tail is
#'   clamped.
#' @param cluster_eps_km if set, compute \strong{A}/\strong{C} per spatial cluster
#'   (bbox) rather than on one domain-wide graph: patches within this distance (km)
#'   share a cluster (\code{\link{cluster_patches}}), and each cluster is routed on its
#'   own small graph - all roads (for the drive-in) plus only that cluster's trails.
#'   \code{NULL} (default) uses a single graph. The per-cluster split is a big win when
#'   patches are scattered; raw travel times are rescaled once, globally, so clusters
#'   stay comparable. Cross-cluster co-visitation is negligible at this separation.
#' @param cluster_buffer_m buffer (m) around each cluster's bbox when selecting its
#'   local trails (default \code{1500}).
#' @param weights per-term multipliers for \code{\link{rank_index}} (default equal).
#' @return \code{patches} with the rescaled term columns, \code{index} and \code{rank}
#'   appended (an \pkg{sf}).
#' @seealso \code{\link{rank_download}}, \code{\link{rank_index}}
#' @export
rank_calculate <- function(
  patches,
  occ,
  suitability,
  records = NULL,
  network = NULL,
  origin = NULL,
  dem = NULL,
  resistance = NULL,
  agg = 10,
  area_col = "acres",
  prob_col = "prob_mean",
  sigma = 100,
  target_area = 50,
  cap_q = 0.95,
  k = 3,
  w_habitat = 5,
  cores = 1,
  speeds = osm_speeds,
  cluster_eps_km = NULL,
  cluster_buffer_m = 1500,
  weights = NULL
) {
  patches <- sf::st_as_sf(patches)
  suit <- if (inherits(suitability, "SpatRaster")) {
    suitability
  } else {
    terra::rast(suitability)
  }
  tmpl <- if (agg > 1) {
    terra::aggregate(suit, agg, fun = "mean", na.rm = TRUE)
  } else {
    suit
  }
  cen <- terra::centroids(terra::vect(patches))
  samp <- function(r) terra::extract(r, cen)[, 2]

  terms <- list()

  # Dg - geographic distance to nearest known population.
  terms$Dg <- samp(geo_distance(occ, tmpl, invert = TRUE))

  # Dr - resistance distance over inverted-suitability friction.
  fric <- if (is.null(resistance)) {
    build_resistance(tmpl, habitat = (1 - tmpl), w_habitat = w_habitat)
  } else {
    terra::resample(
      if (inherits(resistance, "SpatRaster")) {
        resistance
      } else {
        terra::rast(resistance)
      },
      tmpl
    )
  }
  terms$Dr <- samp(cost_distance(fric, occ, template = tmpl, invert = TRUE))

  # S - survey intensity (if records supplied). Evaluate the gridless field directly
  # at the centroids (no full-raster render); negative intensity so rank_index's
  # rescale makes well-surveyed low and unsurveyed high.
  if (!is.null(records)) {
    records <- sf::st_transform(sf::st_as_sf(records), sf::st_crs(tmpl))
    rc <- sf::st_coordinates(records)[, 1:2, drop = FALSE]
    bas <- if ("basisOfRecord" %in% names(records)) {
      records$basisOfRecord
    } else {
      NULL
    }
    fld <- survey_field(
      rc,
      records$speciesKey,
      sigma = sigma,
      basis = bas,
      domain = terra::ext(tmpl)
    )
    terms$S <- -eval_survey(fld, terra::crds(cen))
  }

  # A, C - accessibility and complementarity over the network (if supplied).
  # Processed per spatial cluster (bbox) when cluster_eps_km is set: each cluster gets
  # its own small graph (all roads for the drive-in + only that bbox's trails), so the
  # work scales with cluster size, not the whole domain. Raw hours are collected and
  # rescaled once, globally (by rank_index), so bboxes stay comparable.
  if (!is.null(network) && !is.null(origin)) {
    n <- nrow(patches)
    acc_hr <- rep(NA_real_, n)
    asm_hr <- rep(NA_real_, n)
    run_block <- function(idx, net_b) {
      ab <- accessibility(
        net_b,
        patches[idx, ],
        origins = origin,
        dem = dem,
        k = k,
        speeds = speeds
      )
      acc_hr[idx] <<- ab$patches$access_hr
      asm_hr[idx] <<- complementarity(
        ab$net,
        ab$patch_nodes,
        areas = patches[[area_col]][idx],
        target_area = target_area,
        cap_q = cap_q,
        cores = cores
      )$assemble_hr
    }
    if (is.null(cluster_eps_km)) {
      run_block(seq_len(n), network)
    } else {
      cl <- cluster_patches(patches, eps_km = cluster_eps_km)$cluster
      roads <- network[!is.na(network$class) & network$class == "road", ]
      trails <- network[!is.na(network$class) & network$class == "trail", ]
      for (gid in unique(cl)) {
        idx <- which(cl == gid)
        bb <- sf::st_buffer(
          sf::st_as_sfc(sf::st_bbox(patches[idx, ])),
          cluster_buffer_m
        )
        tl <- trails[lengths(sf::st_intersects(trails, bb)) > 0, ]
        run_block(idx, rbind(roads, tl)) # all roads (drive-in) + local trails
      }
    }
    terms$A <- -acc_hr # rank_index rescales: low hr -> high
    terms$C <- -asm_hr
  }

  # P - model suitability of the patch itself (likelier real habitat).
  if (!is.null(prob_col) && prob_col %in% names(patches)) {
    terms$P <- patches[[prob_col]]
  }

  scored <- do.call(rank_index, c(terms, list(weights = weights)))
  sf::st_sf(
    data.frame(sf::st_drop_geometry(patches), scored, check.names = FALSE),
    geometry = sf::st_geometry(patches)
  )
}

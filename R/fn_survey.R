#' Survey-intensity surface (the \code{S} term) as a continuous Gaussian field
#'
#' Builds the manuscript's \strong{survey intensity} term \code{S} - the
#' \dQuote{bias surface} - from target-group occurrence records (a GBIF pull of
#' co-occurring taxa), as a continuous field of the landscape rather than a grid.
#' The estimator is a weighted sum of isotropic Gaussian kernels, one per record:
#'
#' \deqn{S(x) \;=\; \sum_{j}\, w_j \sum_{i \in j}
#'       \exp\!\Big(-\frac{\lVert x - p_{ij} \rVert^2}{2\sigma^2}\Big),}
#'
#' where \eqn{p_{ij}} is record \eqn{i} of species \eqn{j}, \eqn{\sigma} is the
#' single search-radius bandwidth, and \eqn{w_j} is a per-species weight.
#'
#' \strong{Why it is built this way}
#' \itemize{
#'   \item \emph{Gridless / resolution-free.} \eqn{S(x)} is a closed-form function
#'     of position, defined everywhere. Points are \strong{never} binned to a grid
#'     before modelling; the model \emph{is} the kernel sum. A raster is only ever a
#'     downstream \emph{view} of the field, rendered at whatever resolution the user
#'     asks for (\code{\link{survey_raster}}), and two resolutions are two views of
#'     one model.
#'   \item \emph{Additive across species.} The outer sum is over species, so each
#'     taxon contributes an independent layer \eqn{w_j K_j(x)}. A species can be added
#'     or dropped by adding/subtracting its term; \code{\link{eval_survey}} can be
#'     restricted to a subset of species to recover any single layer.
#'   \item \emph{Inverse-frequency weighting, domain-corrected} (see
#'     \code{\link{survey_weights}}). Common taxa are uninformative about \emph{effort}
#'     (they are everywhere); a record of a seldom-collected taxon marks a careful
#'     search. Let \eqn{n_j} be the record count and \eqn{\varphi_j} the proportion of
#'     the species' \strong{p95 bounding box} that falls inside the domain. The
#'     effective in-domain frequency is \eqn{f_j = n_j / \varphi_j} and
#'     \eqn{w_j = (\varphi_j / n_j)^{\mathrm{damp}}}. The \eqn{\varphi_j} correction
#'     stops a species whose range merely clips the domain edge from looking
#'     spuriously rare (and so over-weighted). Because \eqn{\varphi_j \le 1 \le n_j},
#'     the raw weight \eqn{w_j \in (0, 1]} needs no cap: a fully-in-domain singleton
#'     earns the maximum weight 1, a common or edge-clipping taxon decays toward 0.
#' }
#'
#' \strong{Direction into the index.} Well-surveyed ground is \emph{less} likely to
#' hide an undocumented population, so the \code{RankIndex} wants survey
#' \emph{sparsity}: render with \code{invert = TRUE} to get \eqn{1 - \tilde S}, high
#' where nobody has looked.
#'
#' \pkg{terra} for the raster view and \pkg{sf} for the p95-box/domain overlap. The
#' kernel is truncated at \code{trunc}\eqn{\,\sigma} (tails below \eqn{e^{-8}} at
#' \code{trunc = 4}) and evaluated with a tiled bounding-box prefilter, so no
#' kd-tree dependency and no \eqn{k}-neighbour cap - the sum is exact to the tail.
#'
#' @name survey
NULL

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

#' Build the survey-intensity surface in one call
#'
#' The package's front door for the \code{S} term: weights the records
#' (\code{\link{survey_weights}}), assembles the continuous field
#' (\code{\link{survey_field}}) and renders it to a raster view
#' (\code{\link{survey_raster}}). The field is built once and never pre-binned; the
#' raster is only a view at the resolution of \code{template}/\code{res}.
#'
#' @param coords two-column matrix/data.frame of record coordinates (metres, in the
#'   domain's planar CRS).
#' @param species vector of species labels, one per record.
#' @param template a \pkg{terra} \code{SpatRaster} (geometry/CRS matched) or a
#'   \code{SpatExtent}; with an extent, give \code{res}.
#' @param res cell size in map units when \code{template} is an extent.
#' @param sigma kernel bandwidth \eqn{\sigma} in metres (default \code{100}).
#' @param domain study-domain polygon for the p95-box correction (\pkg{sf} /
#'   \code{SpatVector} / \code{SpatExtent}); defaults to \code{template}'s extent when
#'   \code{NULL} and a raster/extent is given.
#' @param min_records,p,damp,trunc passed to \code{\link{survey_weights}} /
#'   \code{\link{survey_field}}.
#' @param rescale,q bring the view onto \eqn{[0, 1]} (defaults \code{"quantile"},
#'   \code{0.95}); see \code{\link{survey_raster}}.
#' @param invert if \code{TRUE}, return survey \emph{sparsity} \eqn{1 - \tilde S} - the
#'   form the \code{RankIndex} consumes (well-surveyed ground scores low). Default
#'   \code{FALSE} returns the intensity surface \eqn{S} itself.
#' @param record_type,plot_types,plot_weight plot-vs-opportunistic handling, passed
#'   to \code{\link{survey_field}}. If \code{record_type} is \code{NULL} but
#'   \code{origin} is given, it is derived with \code{\link{guess_record_type}}.
#' @param basis,basis_weights per-record \code{basisOfRecord} and its weight
#'   multipliers, passed to \code{\link{survey_field}} (default up-weights herbarium
#'   specimens 1.5x over observations).
#' @param origin optional dataset/origin labels (one per record); used only to infer
#'   \code{record_type} when that is not supplied.
#' @param weights optional precomputed per-species weights (skips
#'   \code{\link{survey_weights}}); see \code{\link{survey_field}}.
#' @param filename optional output path; \code{...} passes to
#'   \code{terra::writeRaster}.
#' @param ... further arguments passed to \code{terra::writeRaster} (via
#'   \code{\link{survey_raster}}), e.g. \code{overwrite} or \code{gdal}.
#' @return a single-layer \code{SpatRaster} of \eqn{S} (or \eqn{1 - \tilde S} when
#'   \code{invert = TRUE}).
#' @seealso \code{\link{survey_weights}} for the per-species weights/floor,
#'   \code{\link{guess_record_type}} for flagging plot datasets.
#' @export
survey_surface <- function(
  coords,
  species,
  template = NULL,
  res = NULL,
  sigma = 100,
  domain = NULL,
  min_records = 5,
  p = 0.95,
  damp = 1,
  trunc = 4,
  record_type = NULL,
  plot_types = "Plot",
  plot_weight = 1,
  basis = NULL,
  basis_weights = c(PRESERVED_SPECIMEN = 1.5),
  origin = NULL,
  rescale = c("quantile", "max", "none"),
  q = 0.95,
  invert = FALSE,
  weights = NULL,
  filename = "",
  ...
) {
  if (
    is.null(domain) &&
      (inherits(template, "SpatRaster") || inherits(template, "SpatExtent"))
  ) {
    domain <- terra::ext(template)
  }

  if (is.null(record_type) && !is.null(origin)) {
    record_type <- guess_record_type(origin, plot_label = plot_types[1])
  }
  fld <- survey_field(
    coords,
    species,
    sigma = sigma,
    record_type = record_type,
    plot_types = plot_types,
    plot_weight = plot_weight,
    basis = basis,
    basis_weights = basis_weights,
    weights = weights,
    domain = domain,
    min_records = min_records,
    p = p,
    damp = damp,
    trunc = trunc
  )
  survey_raster(
    fld,
    template = template,
    res = res,
    rescale = match.arg(rescale),
    q = q,
    invert = invert,
    filename = filename,
    ...
  )
}

#' Guess record type from a dataset / origin column
#'
#' Flags records that come from structured \strong{vegetation-plot} programmes -
#' where every species present is catalogued, so the record stands for a complete
#' local survey - by pattern-matching a free-text dataset, institution or origin
#' field. A convenience for when the user has not labelled \code{record_type} by hand;
#' always eyeball the result, since origin strings are inconsistent.
#'
#' @param origin character (or factor) vector of dataset/origin labels, one per record.
#' @param plot_patterns case-insensitive regular expressions marking plot programmes.
#'   The defaults cover FIA, AIM, VegBank, NEON, the Carolina Vegetation Survey, NPS
#'   I&M, and generic plot/releve/quadrat/inventory wording; override or extend as
#'   needed.
#' @param plot_label,other_label labels returned for matches and non-matches
#'   (defaults \code{"Plot"} / \code{"Opportunistic"}); \code{NA} origins return
#'   \code{NA}.
#' @return a character vector the length of \code{origin}, suitable to pass as
#'   \code{record_type}.
#' @seealso \code{\link{survey_surface}}, \code{\link{survey_field}}
#' @export
guess_record_type <- function(
  origin,
  plot_patterns = c(
    "vegbank",
    "\\bFIA\\b",
    "\\bAIM\\b",
    "\\bNEON\\b",
    "\\bCVS\\b",
    "carolina veg",
    "\\bNPS\\b",
    "rel[e\u00e9]v[e\u00e9]",
    "quadrat",
    "\\bplot\\b",
    "inventory"
  ),
  plot_label = "Plot",
  other_label = "Opportunistic"
) {
  origin <- as.character(origin)
  rx <- paste(plot_patterns, collapse = "|")
  hit <- grepl(rx, origin, ignore.case = TRUE, perl = TRUE)
  out <- ifelse(hit, plot_label, other_label)
  out[is.na(origin)] <- NA
  out
}

# ---------------------------------------------------------------------------
# Per-species weights
# ---------------------------------------------------------------------------

#' Inverse-frequency species weights, corrected for domain clipping
#'
#' @param coords two-column matrix/data.frame of record coordinates (x, y) in the
#'   domain's planar CRS (metres).
#' @param species vector of species labels, one per record (length \code{nrow(coords)}).
#' @param domain the study domain as an \pkg{sf} polygon or a \pkg{terra}
#'   \code{SpatVector}/\code{SpatExtent}; \code{NULL} skips the correction
#'   (\eqn{\varphi_j \equiv 1}).
#' @param min_records minimum records a species needs to be included (default
#'   \code{5}). Taxa below the floor are dropped entirely - too few collections to
#'   carry a reliable range box or effort signal - not merely down-weighted.
#' @param p inner mass kept by the robust bounding box, as a central probability
#'   (default \code{0.95}); the box spans the \code{(1-p)/2} and \code{1-(1-p)/2}
#'   quantiles of x and y, trimming outlier records.
#' @param damp power applied to the raw weight \eqn{\varphi_j/n_j} (default \code{1};
#'   \code{0.5} softens the down-weighting of common taxa, \code{0} makes every
#'   species equal).
#' @return a \code{data.frame} with one row per species: \code{species}, \code{n}
#'   (records), \code{phi} (\eqn{\varphi_j}), \code{freq} (\eqn{f_j = n_j/\varphi_j})
#'   and \code{w} (the weight), for species clearing \code{min_records}. Row order
#'   follows \code{sort(unique(species))}.
#' @seealso \code{\link{survey_field}}
#' @export
survey_weights <- function(
  coords,
  species,
  domain = NULL,
  min_records = 5,
  p = 0.95,
  damp = 1
) {
  coords <- as.matrix(coords[, 1:2])
  stopifnot(length(species) == nrow(coords))
  lo <- (1 - p) / 2
  qs <- c(lo, 1 - lo)

  dom <- if (is.null(domain)) NULL else .as_sf_poly(domain)
  dom_u <- if (is.null(dom)) NULL else sf::st_union(dom)

  by_sp <- split(seq_len(nrow(coords)), species)
  by_sp <- by_sp[lengths(by_sp) >= min_records] # apply the records floor first
  if (!length(by_sp)) {
    stop("no species clears min_records = ", min_records)
  }
  rows <- lapply(names(by_sp), function(sp) {
    idx <- by_sp[[sp]]
    xy <- coords[idx, , drop = FALSE]
    n <- length(idx)
    bx <- stats::quantile(xy[, 1], qs, names = FALSE, type = 7)
    by <- stats::quantile(xy[, 2], qs, names = FALSE, type = 7)
    area_box <- (bx[2] - bx[1]) * (by[2] - by[1])

    # phi: share of the p95 box inside the domain. A degenerate box (single point
    # or a colinear set, area 0) carries no range information -> treat as local,
    # fully in-domain (phi = 1).
    phi <- 1
    if (!is.null(dom_u) && area_box > 0) {
      box <- sf::st_as_sfc(sf::st_bbox(
        c(xmin = bx[1], ymin = by[1], xmax = bx[2], ymax = by[2]),
        crs = sf::st_crs(dom_u)
      ))
      inter <- suppressWarnings(sf::st_area(sf::st_intersection(box, dom_u)))
      phi <- if (length(inter) == 0) 0 else as.numeric(sum(inter)) / area_box
      phi <- min(max(phi, 0), 1)
    }
    freq <- n / max(phi, .Machine$double.eps)
    data.frame(
      species = sp,
      n = n,
      phi = phi,
      freq = freq,
      w = (phi / n)^damp,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows[order(names(by_sp))])
}

# ---------------------------------------------------------------------------
# The field
# ---------------------------------------------------------------------------

#' Construct the survey-intensity field
#'
#' Bundles the records, their per-record weights and the bandwidth into a
#' lightweight \code{survey_field} object that \code{\link{eval_survey}} and
#' \code{\link{survey_raster}} evaluate. Nothing is discretised here.
#'
#' @param coords two-column matrix/data.frame of record coordinates (metres).
#' @param species vector of species labels (one per record).
#' @param sigma kernel bandwidth \eqn{\sigma} in map units (metres), the radius over
#'   which one record counts ground as surveyed (default \code{100}).
#' @param weights optional per-species weights: a \code{data.frame} as returned by
#'   \code{\link{survey_weights}} (matched on \code{species}), a named numeric vector,
#'   or \code{NULL} to compute them from \code{domain}/\code{min_records}/\code{p}/\code{damp}.
#' @param record_type optional per-record label splitting the two detection
#'   processes. Records whose label is in \code{plot_types} are treated as
#'   \strong{vegetation plots} - a complete floristic inventory at one spot (FIA, AIM,
#'   VegBank, ...), so absence there is strong evidence. Plot records are
#'   \emph{deduplicated by coordinate} (the many species-rows of one plot are a single
#'   survey event, not many) and each surviving plot point carries \code{plot_weight};
#'   they are also held out of the opportunistic frequency counts. \code{NULL} treats
#'   every record as opportunistic. See \code{\link{guess_record_type}} to derive this
#'   from a dataset/origin column.
#' @param plot_types labels in \code{record_type} that mark a plot (default
#'   \code{"Plot"}, matched case-insensitively).
#' @param plot_weight per-record weight for a deduplicated plot point (default
#'   \code{1} - the ceiling of the opportunistic weights, which sit in \eqn{(0, 1]};
#'   raise it to let plots dominate further).
#' @param basis optional per-record \code{basisOfRecord} labels (as from
#'   \code{\link{gbif_records}}); used to up-weight deliberate collections.
#' @param basis_weights named multipliers applied per opportunistic record by its
#'   \code{basis} (default \code{c(PRESERVED_SPECIMEN = 1.5)} - a herbarium specimen
#'   marks survey effort ~50\% more strongly than an iNaturalist photo). Any basis not
#'   named here is neutral (1); the \eqn{n_j \ge 5} floor keeps even a boosted
#'   opportunistic weight below the plot ceiling.
#' @param weights optional per-species weights: a \code{data.frame} as returned by
#'   \code{\link{survey_weights}} (matched on \code{species}), a named numeric vector,
#'   or \code{NULL} to compute them from \code{domain}/\code{min_records}/\code{p}/\code{damp}.
#'   Applied to the opportunistic records only.
#' @param domain,min_records,p,damp passed to \code{\link{survey_weights}} when
#'   \code{weights} is \code{NULL}. Records of any species absent from the weight set
#'   - below the floor, or omitted by the caller - are dropped from the field.
#' @param trunc kernel support in units of \eqn{\sigma} (default \code{4}).
#' @return an object of class \code{survey_field}: a list with \code{coords},
#'   \code{species} (plot points labelled \code{"__plot__"}), per-record \code{w},
#'   \code{sigma}, \code{trunc}, the opportunistic per-species \code{weights} table and
#'   \code{plot_weight}.
#' @seealso \code{\link{eval_survey}}, \code{\link{survey_raster}}
#' @keywords internal
survey_field <- function(
  coords,
  species,
  sigma = 100,
  record_type = NULL,
  plot_types = "Plot",
  plot_weight = 1,
  basis = NULL,
  basis_weights = c(PRESERVED_SPECIMEN = 1.5),
  weights = NULL,
  domain = NULL,
  min_records = 5,
  p = 0.95,
  damp = 1,
  trunc = 4
) {
  coords <- as.matrix(coords[, 1:2])
  storage.mode(coords) <- "double"
  stopifnot(length(species) == nrow(coords), sigma > 0, trunc > 0)
  species <- as.character(species)
  if (!is.null(basis)) {
    stopifnot(length(basis) == nrow(coords))
  }

  is_plot <- logical(nrow(coords))
  if (!is.null(record_type)) {
    stopifnot(length(record_type) == nrow(coords))
    is_plot <- tolower(as.character(record_type)) %in% tolower(plot_types)
  }

  # Plot stream: one survey event per location -> dedup on coords, ceiling weight.
  pc <- coords[0, , drop = FALSE]
  pw <- numeric(0)
  psp <- character(0)
  if (any(is_plot)) {
    cp <- coords[is_plot, , drop = FALSE]
    cp <- cp[!duplicated(cp), , drop = FALSE]
    pc <- cp
    pw <- rep(plot_weight, nrow(cp))
    psp <- rep("__plot__", nrow(cp))
  }

  # Opportunistic stream: inverse-frequency weights, plots excluded from the counts.
  oc <- coords[!is_plot, , drop = FALSE]
  osp <- species[!is_plot]
  ow <- numeric(0)
  if (nrow(oc)) {
    if (is.null(weights)) {
      weights <- survey_weights(
        oc,
        osp,
        domain = domain,
        min_records = min_records,
        p = p,
        damp = damp
      )
    }
    wmap <- if (is.data.frame(weights)) {
      stats::setNames(weights$w, weights$species)
    } else {
      weights
    }
    # Records of species not in the weight set (below the floor, or caller-omitted)
    # are dropped rather than erroring.
    keep <- osp %in% names(wmap)
    oc <- oc[keep, , drop = FALSE]
    osp <- osp[keep]
    ow <- as.numeric(wmap[osp])
    # Basis multiplier: a deliberate herbarium collection marks effort more strongly
    # than a passing iNaturalist photo. Applied per record, to the opportunistic
    # stream only (plots already carry the ceiling weight).
    if (!is.null(basis)) {
      bo <- as.character(basis[!is_plot])[keep]
      m <- basis_weights[bo]
      m[is.na(m)] <- 1 # unlisted basis -> neutral
      ow <- ow * as.numeric(m)
    }
  }

  coords <- rbind(oc, pc)
  species <- c(osp, psp)
  w <- c(ow, pw)
  if (!length(w)) {
    stop("no records remain after applying record types / the floor")
  }

  structure(
    list(
      coords = coords,
      species = species,
      w = w,
      sigma = sigma,
      trunc = trunc,
      plot_weight = plot_weight,
      weights = if (is.data.frame(weights)) weights else NULL
    ),
    class = "survey_field"
  )
}

#' Evaluate the field at arbitrary locations
#'
#' Computes \eqn{S(x)} at any set of query points - the whole point of keeping the
#' model gridless. Records are indexed into a \code{trunc}\eqn{\sigma} bucket grid, and
#' each query is summed only against records in its own and the eight neighbouring
#' buckets, so cost is local (\eqn{\propto} records within support) regardless of how
#' widely the queries are scattered - not the query count times the record count.
#'
#' @param field a \code{survey_field}.
#' @param xy two-column matrix/data.frame of query coordinates (same CRS as the
#'   records).
#' @param species optional subset of species labels; restricts the sum to those
#'   taxa (recovers a single additive layer, or any partial sum).
#' @param chunk unused; kept for back-compatibility.
#' @return numeric vector of \eqn{S} values, length \code{nrow(xy)}.
#' @keywords internal
eval_survey <- function(field, xy, species = NULL, chunk = 2048L) {
  stopifnot(inherits(field, "survey_field"))
  xy <- as.matrix(xy[, 1:2, drop = FALSE])
  storage.mode(xy) <- "double"

  cd <- field$coords
  wd <- field$w
  if (!is.null(species)) {
    keep <- field$species %in% species
    cd <- cd[keep, , drop = FALSE]
    wd <- wd[keep]
  }
  out <- numeric(nrow(xy))
  if (!length(wd) || !nrow(xy)) {
    return(out)
  }

  bw <- field$trunc * field$sigma
  denom <- 2 * field$sigma^2
  bw2 <- bw^2

  # Bucket records on a bw grid; key each cell (offset to keep indices non-negative).
  ox <- floor(min(cd[, 1], xy[, 1]) / bw) - 1
  oy <- floor(min(cd[, 2], xy[, 2]) / bw) - 1
  rbx <- floor(cd[, 1] / bw) - ox
  rby <- floor(cd[, 2] / bw) - oy
  rec_by <- split(seq_along(wd), rbx + rby * 1e6) # distinct keys, no collision

  # Group queries by bucket, then sum each group against its 3x3 record neighbourhood.
  qbx <- floor(xy[, 1] / bw) - ox
  qby <- floor(xy[, 2] / bw) - oy
  for (qi in split(seq_len(nrow(xy)), qbx + qby * 1e6)) {
    bx <- qbx[qi[1]]
    by <- qby[qi[1]]
    cand <- unlist(
      lapply((bx - 1):(bx + 1), function(ix) {
        unlist(
          lapply((by - 1):(by + 1), function(iy) {
            rec_by[[as.character(ix + iy * 1e6)]]
          }),
          use.names = FALSE
        )
      }),
      use.names = FALSE
    )
    if (!length(cand)) {
      next
    }
    d2 <- outer(xy[qi, 1], cd[cand, 1], "-")^2 +
      outer(xy[qi, 2], cd[cand, 2], "-")^2
    k <- exp(-d2 / denom)
    k[d2 > bw2] <- 0
    out[qi] <- as.vector(k %*% wd[cand])
  }
  out
}

#' Render the field to a raster view
#'
#' Evaluates \eqn{S(x)} at the cell centres of a template, tile by tile. This is a
#' \emph{view} of the continuous model at a chosen resolution, not the model itself -
#' call it again at a different resolution for a different view.
#'
#' @param field a \code{survey_field}.
#' @param template a \pkg{terra} \code{SpatRaster} whose geometry/CRS to match, or an
#'   \code{SpatExtent}; required alongside \code{res} when no template raster is given.
#' @param res cell size in map units when building from an extent (ignored if
#'   \code{template} is a \code{SpatRaster}).
#' @param rescale one of \code{"quantile"} (divide by the \code{q} quantile, clamped
#'   to 1; the default - \code{"max"} is hostage to a single survey hotspot, which
#'   flattens all other structure), \code{"max"} (divide by the max) or \code{"none"},
#'   to bring the view onto \eqn{[0, 1]}.
#' @param q upper quantile for \code{rescale = "quantile"} (default \code{0.95}: about
#'   the top 5 percent of the surface saturates to 1, giving the sparsity surface its
#'   fullest dynamic range without one hotspot owning the scale).
#' @param invert if \code{TRUE}, return survey \emph{sparsity} \eqn{1 - \tilde S}
#'   (requires a \code{rescale} other than \code{"none"}); this is the form the
#'   \code{RankIndex} consumes.
#' @param filename optional output path (written via \code{terra::writeRaster}).
#' @param ... passed to \code{terra::writeRaster}.
#' @return a single-layer \code{SpatRaster}.
#' @keywords internal
survey_raster <- function(
  field,
  template = NULL,
  res = NULL,
  rescale = c("quantile", "max", "none"),
  q = 0.95,
  invert = FALSE,
  filename = "",
  ...
) {
  stopifnot(inherits(field, "survey_field"))
  rescale <- match.arg(rescale)
  if (invert && rescale == "none") {
    stop(
      "invert = TRUE needs rescale = 'max' or 'quantile' (an unbounded field has no complement)"
    )
  }

  if (inherits(template, "SpatRaster")) {
    r <- terra::rast(template, nlyrs = 1)
  } else {
    ext <- if (inherits(template, "SpatExtent")) {
      template
    } else {
      terra::ext(template)
    }
    if (is.null(res)) {
      stop("supply 'res' when building from an extent")
    }
    r <- terra::rast(ext, resolution = res)
  }
  names(r) <- "S"

  # Tile over blocks so each eval_survey() call sees a localised query envelope.
  bs <- terra::blocks(r)
  terra::writeStart(r, filename = filename, overwrite = TRUE, ...)
  for (b in seq_len(bs$n)) {
    rows <- bs$row[b]:(bs$row[b] + bs$nrows[b] - 1)
    cells <- terra::cellFromRowColCombine(r, rows, seq_len(ncol(r)))
    xy <- terra::xyFromCell(r, cells)
    v <- eval_survey(field, xy, chunk = length(cells))
    terra::writeValues(r, v, bs$row[b], bs$nrows[b])
  }
  terra::writeStop(r)

  if (rescale != "none") {
    denom <- if (rescale == "max") {
      terra::global(r, "max", na.rm = TRUE)[[1]]
    } else {
      terra::global(r, fun = function(x) stats::quantile(x, q, na.rm = TRUE))[[
        1
      ]]
    }
    if (is.finite(denom) && denom > 0) {
      r <- terra::clamp(r / denom, 0, 1)
      names(r) <- "S"
    }
    if (invert) {
      r <- 1 - r
      names(r) <- "S"
    }
  }
  r
}

# ---------------------------------------------------------------------------
# internal
# ---------------------------------------------------------------------------

# Coerce a domain argument (sf polygon, SpatVector, or SpatExtent) to sf polygons.
.as_sf_poly <- function(x) {
  if (inherits(x, "sf") || inherits(x, "sfc")) {
    return(sf::st_as_sf(x))
  }
  if (inherits(x, "SpatExtent")) {
    x <- terra::as.polygons(x)
  }
  if (inherits(x, "SpatVector")) {
    return(sf::st_as_sf(x))
  }
  stop("domain must be an sf/sfc polygon, a terra SpatVector, or a SpatExtent")
}

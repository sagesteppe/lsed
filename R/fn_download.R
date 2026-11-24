#' Acquire every external input for the patch ranking (download module)
#'
#' The data-acquisition half of the patch ranking, kept separate from the calculation
#' so the slow, network-bound, API-dependent work runs once and its outputs can be
#' re-used. It overlaps the two big pulls: GBIF's bulk download is \strong{requested}
#' first (and prepared server-side while we wait), the OSM road/trail network is
#' fetched in that window, and only then do we come \strong{back} to collect the
#' finished GBIF archive - so the GBIF prep time is spent fetching OSM, not idling.
#'
#' \preformatted{
#'   gbif_request()  --->  (GBIF prepares server-side)  ---.
#'                                                          |
#'   osm_network_for()  (runs during the wait)             |
#'                                                          v
#'                                                   gbif_retrieve()
#' }
#'
#' Needs a GBIF account (see \code{\link{gbif_request}}). Everything is written to disk
#' (GeoPackages), so a later \code{rank} calculation reads files, not live APIs.
#'
#' @param patches \pkg{sf} patches (points/polygons) that scope both pulls.
#' @param origin trip origin for accessibility - \pkg{sf} point or \code{c(lon, lat)}
#'   (see \code{\link{osm_network_for}}).
#' @param crs planar working CRS (metres); defaults to the patches' CRS.
#' @param taxon_key,basis,year_from,coord_uncertainty_max GBIF filters
#'   (\code{\link{gbif_request}}).
#' @param gbif_path,osm_path output GeoPackages for the records and the network.
#' @param eps_km,buffer_m cluster-scoping for the OSM pull
#'   (\code{\link{osm_network_for}}).
#' @param ... further arguments to \code{\link{osm_network_for}} (e.g.
#'   \code{connect_roads}, \code{endpoint}, \code{contact}, \code{pause}).
#' @return a list: \code{records} (GBIF \pkg{sf}), \code{network} (OSM \pkg{sf}),
#'   \code{origin} (\pkg{sf} point), \code{clusters}, and \code{doi} - everything the
#'   calculation step needs.
#' @seealso \code{\link{gbif_request}}, \code{\link{osm_network_for}},
#'   \code{\link{rank_index}}
#' @export
rank_download <- function(
  patches,
  origin,
  crs = NULL,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  gbif_path = "data/gbif_records.gpkg",
  osm_path = "data/osm_network.gpkg",
  eps_km = 5,
  buffer_m = 1500,
  ...
) {
  pcrs <- if (!is.null(crs)) sf::st_crs(crs) else sf::st_crs(patches)

  # 1. Kick off the GBIF job - returns at once, GBIF prepares it server-side.
  key <- gbif_request(
    patches,
    taxon_key = taxon_key,
    basis = basis,
    year_from = year_from,
    coord_uncertainty_max = coord_uncertainty_max
  )

  # 2. Fetch OSM while GBIF prepares (this is the overlap that saves the wait).
  message("Fetching OSM network while GBIF prepares the download...")
  net <- osm_network_for(
    patches,
    origin,
    crs = pcrs,
    eps_km = eps_km,
    buffer_m = buffer_m,
    path = osm_path,
    ...
  )

  # 3. Come back for the finished GBIF archive (usually ready by now).
  message("Collecting the GBIF download...")
  recs <- gbif_retrieve(key, path = gbif_path, crs = pcrs)

  list(
    records = recs,
    network = net$network,
    origin = net$origin,
    clusters = net$clusters,
    doi = attr(recs, "doi")
  )
}


# ===========================================================================
# GBIF acquisition (merged from fn_gbif.R)
# ===========================================================================

#' Fetch target-group occurrence records from GBIF for the survey-intensity term
#'
#' Pulls occurrences inside a bounding box from GBIF as \pkg{sf} points, ready to feed
#' \code{\link{survey_surface}} as the target-group records for \strong{S}. The pull
#' uses GBIF's server-side \strong{bulk download} (\code{rgbif::occ_download}) - one
#' prepared job rather than thousands of fragile paged requests, and the route GBIF
#' asks heavy users to take. \code{count_only = TRUE} first (no account needed) to see
#' the filtered total before committing.
#'
#' \strong{Requires a free GBIF account} for the download (not for the count). Register
#' at \url{https://www.gbif.org/}, then set \code{GBIF_USER}, \code{GBIF_PWD} and
#' \code{GBIF_EMAIL} (e.g. in \code{~/.Renviron}) or pass them as arguments. A download
#' is minted under your account and citable by its DOI.
#'
#' \strong{Filtering is the point.} A raw vascular-plant pull is swamped by imprecise
#' iNaturalist observations. \code{year_from} and \code{coord_uncertainty_max} trim to
#' records fit to mark \emph{where a careful collection happened}. The uncertainty
#' filter also drops records with \emph{no} uncertainty recorded, which is most of them
#' - so it defaults to \code{NA} (off); set e.g. \code{100} only if you want to keep
#' solely well-located records.
#'
#' @param bbox the area: an \pkg{sf}/\pkg{terra} object (extent used), or numeric
#'   \code{c(xmin, ymin, xmax, ymax)} in lon/lat.
#' @param taxon_key GBIF backbone key to restrict to (default \code{7707728},
#'   Tracheophyta / vascular plants).
#' @param basis \code{basisOfRecord} values to keep (default preserved specimens +
#'   human observations).
#' @param year_from earliest year to keep (default \code{1990}); \code{NA} disables.
#' @param coord_uncertainty_max max coordinate uncertainty in metres (default
#'   \code{NA} = off, since the field is rarely populated); a number also drops records
#'   lacking the field.
#' @param crs output CRS (default lon/lat).
#' @param count_only if \code{TRUE}, return just the filtered record count - a cheap
#'   request, no account, no download.
#' @param path GeoPackage to write the records to (\code{NULL} ->
#'   \code{gbif_records.gpkg} in the working directory).
#' @param download_dir where to save the GBIF download zip (\code{NULL} -> beside
#'   \code{path}); kept so the costly job need not be re-run.
#' @param user,pwd,email GBIF credentials (default the \code{GBIF_USER}/\code{GBIF_PWD}/
#'   \code{GBIF_EMAIL} environment variables).
#' @param poll seconds between status checks while the download is prepared (default
#'   \code{30}).
#' @return with \code{count_only}, an integer. Otherwise an \pkg{sf} of \code{POINT}s
#'   with \code{speciesKey}, \code{species}, \code{basisOfRecord},
#'   \code{coordinateUncertaintyInMeters} and \code{year}; attributes \code{path} (file
#'   written) and \code{doi} (citable download). Pass its coords + \code{speciesKey} to
#'   \code{\link{survey_surface}}.
#' @seealso \code{\link{survey_surface}}
#' @export
gbif_records <- function(
  bbox,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  crs = NULL,
  count_only = FALSE,
  path = NULL,
  download_dir = NULL,
  user = Sys.getenv("GBIF_USER"),
  pwd = Sys.getenv("GBIF_PWD"),
  email = Sys.getenv("GBIF_EMAIL"),
  poll = 30
) {
  bb <- .lonlat_bbox(bbox)
  wkt <- rgbif::gbif_bbox2wkt(bb$box[1], bb$box[2], bb$box[3], bb$box[4])
  out_crs <- if (!is.null(crs)) {
    sf::st_crs(crs)
  } else if (!is.na(bb$crs)) {
    bb$crs
  } else {
    sf::st_crs(4326)
  }

  # --- count: a cheap pre-check, no account (vector basis trips occ_search, so
  # count each stream and sum) ---
  if (count_only) {
    qargs <- list(taxonKey = taxon_key, geometry = wkt, hasCoordinate = TRUE)
    if (!is.na(year_from)) {
      qargs$year <- paste0(year_from, ",", as.integer(format(Sys.Date(), "%Y")))
    }
    if (!is.na(coord_uncertainty_max)) {
      qargs$coordinateUncertaintyInMeters <- paste0("0,", coord_uncertainty_max)
    }
    counts <- vapply(
      basis,
      function(b) {
        n <- do.call(
          rgbif::occ_search,
          c(qargs, list(basisOfRecord = b, limit = 1))
        )$meta$count
        if (is.null(n)) 0L else as.integer(n)
      },
      integer(1)
    )
    return(sum(counts))
  }

  # Blocking convenience: request, wait, retrieve.
  key <- gbif_request(
    bbox,
    taxon_key = taxon_key,
    basis = basis,
    year_from = year_from,
    coord_uncertainty_max = coord_uncertainty_max,
    user = user,
    pwd = pwd,
    email = email
  )
  gbif_retrieve(
    key,
    path = path,
    download_dir = download_dir,
    crs = out_crs,
    poll = poll
  )
}

#' Request a GBIF download (non-blocking) - stage 1 of 2
#'
#' Submits the download predicate to GBIF and returns immediately with the job key,
#' \strong{without} waiting for the server to prepare the archive. Do other work (e.g.
#' the OSM pull) while GBIF builds it, then collect with \code{\link{gbif_retrieve}}.
#' Arguments mirror \code{\link{gbif_records}}.
#'
#' @inheritParams gbif_records
#' @return the \code{occ_download} job key (pass to \code{\link{gbif_retrieve}}).
#' @seealso \code{\link{gbif_retrieve}}, \code{\link{gbif_records}}
#' @export
gbif_request <- function(
  bbox,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  user = Sys.getenv("GBIF_USER"),
  pwd = Sys.getenv("GBIF_PWD"),
  email = Sys.getenv("GBIF_EMAIL")
) {
  if (!nzchar(user) || !nzchar(pwd) || !nzchar(email)) {
    stop(
      "GBIF download needs an account: set GBIF_USER, GBIF_PWD, GBIF_EMAIL ",
      "(register free at gbif.org), or pass user/pwd/email. Use count_only = TRUE ",
      "to preview counts without an account."
    )
  }
  bb <- .lonlat_bbox(bbox)
  wkt <- rgbif::gbif_bbox2wkt(bb$box[1], bb$box[2], bb$box[3], bb$box[4])

  preds <- list(
    rgbif::pred("taxonKey", taxon_key),
    rgbif::pred("hasCoordinate", TRUE),
    rgbif::pred_in("basisOfRecord", basis),
    rgbif::pred_within(wkt)
  )
  if (!is.na(year_from)) {
    preds <- c(preds, list(rgbif::pred_gte("year", year_from)))
  }
  if (!is.na(coord_uncertainty_max)) {
    preds <- c(
      preds,
      list(rgbif::pred_lte(
        "coordinateUncertaintyInMeters",
        coord_uncertainty_max
      ))
    )
  }

  key <- do.call(
    rgbif::occ_download,
    c(preds, list(format = "SIMPLE_CSV", user = user, pwd = pwd, email = email))
  )
  message(
    "GBIF download requested: ",
    key,
    " - preparing server-side (non-blocking)."
  )
  key
}

#' Retrieve a requested GBIF download - stage 2 of 2
#'
#' Waits for the \code{\link{gbif_request}} job to finish preparing (usually already
#' done if you did other work in between), downloads the archive, imports it, and
#' writes \pkg{sf} points.
#'
#' @param key the job key from \code{\link{gbif_request}}.
#' @param path,download_dir,crs,poll as in \code{\link{gbif_records}}.
#' @return an \pkg{sf} of points; attributes \code{path} and \code{doi}.
#' @seealso \code{\link{gbif_request}}
#' @export
gbif_retrieve <- function(
  key,
  path = NULL,
  download_dir = NULL,
  crs = NULL,
  poll = 30
) {
  out_crs <- if (is.null(crs)) sf::st_crs(4326) else sf::st_crs(crs)
  rgbif::occ_download_wait(key, status_ping = poll, quiet = FALSE)

  if (is.null(path)) {
    path <- file.path(getwd(), "gbif_records.gpkg")
  }
  if (is.null(download_dir)) {
    download_dir <- dirname(path)
  }
  dir.create(download_dir, showWarnings = FALSE, recursive = TRUE)
  zf <- rgbif::occ_download_get(key, path = download_dir, overwrite = TRUE)
  occ <- rgbif::occ_download_import(zf)

  res <- .gbif_occ_to_sf(occ, out_crs)
  sf::st_write(res, path, quiet = TRUE, delete_dsn = TRUE)
  doi <- tryCatch(as.character(attr(key, "doi")), error = function(e) {
    NA_character_
  })
  doi <- if (length(doi)) doi[1] else NA_character_ # attr may be NULL / length 0
  message(sprintf(
    "gbif_retrieve: %d records -> %s%s",
    nrow(res),
    path,
    if (!is.na(doi)) paste0("  (DOI: ", doi, ")") else ""
  ))
  structure(res, path = path, doi = doi)
}


# ===========================================================================
# OSM acquisition (merged from fn_osm.R)
# ===========================================================================

#' Cluster patches into spatial groups
#'
#' Groups patch centroids that lie within \code{eps_km} of one another (a
#' within-distance graph, connected components), so OSM can be fetched only where
#' patches actually are rather than across the empty country between them.
#'
#' @param patches \pkg{sf} points or polygons.
#' @param eps_km join distance in km: patches within this of each other share a cluster
#'   (default \code{5}).
#' @param crs planar CRS (metres) for the distance test; defaults to the patches' CRS.
#' @return the patch centroids as \pkg{sf} points with a \code{cluster} id column.
#' @export
cluster_patches <- function(patches, eps_km = 5, crs = NULL) {
  if (!is.null(crs)) {
    patches <- sf::st_transform(patches, sf::st_crs(crs))
  }
  cen <- sf::st_as_sf(sf::st_centroid(sf::st_geometry(patches)))
  nb <- sf::st_is_within_distance(cen, dist = eps_km * 1000)
  g <- igraph::graph_from_adj_list(nb, mode = "all")
  cen$cluster <- igraph::components(g)$membership
  cen
}

#' Fetch the OSM access network (roads + trails) for a domain
#'
#' A convenience fetcher for the \strong{A} (accessibility) and \strong{C}
#' (complementarity) terms: pulls the OpenStreetMap highway network inside a bounding
#' box from an Overpass endpoint and returns it as \pkg{sf} lines, ready to pass as
#' \code{sources} to \code{\link{cost_distance}}. OpenTrailMap and similar viewers are
#' just renderers of this same OSM data.
#'
#' \strong{Be a good citizen.} Public Overpass instances are a shared, volunteer-run
#' resource with a tight usage policy. This helper makes only modest promises and
#' tries to behave:
#' \itemize{
#'   \item \strong{Batches} a large domain into \code{tiles}^2 smaller queries rather
#'     than one giant one.
#'   \item \strong{Checkpoints} every tile to \code{cache_dir} the moment it returns,
#'     and on a re-run \strong{skips} any tile already cached - so an interrupted or
#'     retried pull resumes instead of re-hammering the API.
#'   \item \strong{Breathes} between calls (\code{req_throttle}) and \strong{backs off}
#'     exponentially on transient failures / rate limits (429/502/503/504, honouring
#'     any \code{Retry-After}).
#'   \item Sends a plain \strong{User-Agent} and never your identity. If you have a
#'     contact address you are willing to share per OSM etiquette, pass it in
#'     \code{contact} - it is \emph{opt-in}, never read from your session.
#' }
#' For anything heavy, run your \strong{own Overpass instance} (or a provider you have
#' an account with) and point \code{endpoint} at it - do not hammer the public API.
#'
#' Data is \eqn{\copyright} OpenStreetMap contributors, \strong{ODbL}: attribute it,
#' and snapshot the result (the \code{timestamp} attribute records the OSM base time)
#' so analyses stay reproducible as OSM changes.
#'
#' @param bbox the domain: an \pkg{sf}/\pkg{terra} object (its extent is used), or a
#'   numeric \code{c(xmin, ymin, xmax, ymax)} in lon/lat (EPSG:4326).
#' @param crs output CRS (anything \code{sf::st_crs} accepts). Defaults to the input
#'   object's CRS, else lon/lat.
#' @param roads,trails OSM \code{highway} values to treat as each class; the returned
#'   lines carry a \code{class} column ("road"/"trail"). Set either to
#'   \code{character(0)} to skip it.
#' @param path file to write the merged network to (GeoPackage). \code{NULL} (default)
#'   writes \code{osm_access.gpkg} in the working directory.
#' @param cache_dir directory for per-tile checkpoints (one \code{.rds} per tile).
#'   \code{NULL} (default) uses a folder named after \code{path} beside it. Existing
#'   tiles here are reused unless \code{overwrite = TRUE}; delete it to force a fresh
#'   pull.
#' @param overwrite refetch and overwrite cached tiles (default \code{FALSE}).
#' @param endpoint Overpass API URL (default the public instance - override for your
#'   own).
#' @param contact optional contact string appended to the User-Agent (opt-in; e.g. a
#'   project URL or email you choose to share). \code{NULL} sends none.
#' @param tiles split the bbox into a \code{tiles} x \code{tiles} grid of requests
#'   (default \code{1}).
#' @param exclude optional geometry (\pkg{sf}/\pkg{sfc}, any CRS) of ground already
#'   covered elsewhere; any tile falling \emph{entirely} within it is skipped - never
#'   fetched - so overlapping pulls don't re-query the API. Its benefit grows as tiles
#'   shrink toward the excluded regions' size.
#' @param pause minimum seconds between requests (default \code{1}); also the base of
#'   the retry backoff.
#' @param max_tries attempts per tile before giving up (default \code{4}).
#' @param timeout Overpass server-side \code{[timeout:]} seconds (default \code{50}).
#' @return an \pkg{sf} object of \code{LINESTRING}s with \code{osm_id}, \code{highway}
#'   and \code{class} columns, in \code{crs}; attributes \code{timestamp} (OSM base
#'   time) and \code{path} (where it was written). Pass straight to
#'   \code{\link{cost_distance}} as \code{sources}.
#' @export
osm_access <- function(
  bbox,
  crs = NULL,
  roads = c(
    "motorway",
    "trunk",
    "primary",
    "secondary",
    "tertiary",
    "unclassified",
    "residential",
    "service",
    "living_street",
    "road"
  ),
  trails = c("path", "footway", "track", "bridleway", "cycleway", "steps"),
  path = NULL,
  cache_dir = NULL,
  overwrite = FALSE,
  endpoint = "https://overpass-api.de/api/interpreter",
  contact = NULL,
  tiles = 1L,
  exclude = NULL,
  pause = 1,
  max_tries = 4L,
  timeout = 50
) {
  hw <- c(roads, trails)
  if (!length(hw)) {
    stop("nothing to fetch: both 'roads' and 'trails' are empty")
  }

  bb <- .lonlat_bbox(bbox) # list(box = c(xmin,ymin,xmax,ymax), crs)
  out_crs <- if (!is.null(crs)) {
    sf::st_crs(crs)
  } else if (!is.na(bb$crs)) {
    bb$crs
  } else {
    sf::st_crs(4326)
  }

  # Output + checkpoint locations.
  if (is.null(path)) {
    path <- file.path(getwd(), "osm_access.gpkg")
  }
  if (is.null(cache_dir)) {
    cache_dir <- file.path(
      dirname(path),
      paste0(tools::file_path_sans_ext(basename(path)), "_tiles")
    )
  }
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  ua <- paste0(
    "lsed-osm/0.1 (R; polite)",
    if (!is.null(contact)) paste0(" ", contact)
  )
  rx <- paste(hw, collapse = "|")

  # One throttled, backing-off request for a single lon/lat box -> parsed JSON.
  fetch_box <- function(b) {
    ql <- sprintf(
      "[out:json][timeout:%d];(way[\"highway\"~\"^(%s)$\"](%.6f,%.6f,%.6f,%.6f););out geom;",
      timeout,
      rx,
      b[2],
      b[1],
      b[4],
      b[3]
    ) # Overpass order: S,W,N,E
    resp <- httr2::request(endpoint) |>
      httr2::req_user_agent(ua) |>
      httr2::req_body_form(data = ql) |>
      httr2::req_timeout(timeout + 15) |>
      httr2::req_throttle(capacity = 1, fill_time_s = pause) |>
      httr2::req_retry(
        max_tries = max_tries,
        backoff = function(i) min(60, pause * 2^i),
        is_transient = function(r) {
          httr2::resp_status(r) %in% c(429, 502, 503, 504)
        }
      ) |>
      httr2::req_perform()
    jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)
  }

  # Any ground already covered elsewhere - tiles fully inside it are never fetched.
  excl <- if (!is.null(exclude)) {
    sf::st_union(sf::st_transform(sf::st_geometry(sf::st_as_sf(exclude)), 4326))
  }

  # Batch into tiles; checkpoint each, skip ones already on disk or excluded.
  xs <- seq(bb$box[1], bb$box[3], length.out = tiles + 1L)
  ys <- seq(bb$box[2], bb$box[4], length.out = tiles + 1L)
  grid <- expand.grid(i = seq_len(tiles), j = seq_len(tiles))
  tiles_sf <- vector("list", nrow(grid))
  for (g in seq_len(nrow(grid))) {
    i <- grid$i[g]
    j <- grid$j[g]
    tb <- c(xs[i], ys[j], xs[i + 1L], ys[j + 1L])
    # Skip a tile fully within already-covered ground - don't hit the API for it.
    if (!is.null(excl)) {
      tpoly <- sf::st_as_sfc(sf::st_bbox(
        c(xmin = tb[1], ymin = tb[2], xmax = tb[3], ymax = tb[4]),
        crs = 4326
      ))
      if (as.logical(sf::st_covered_by(tpoly, excl, sparse = FALSE))) {
        tiles_sf[[g]] <- .empty_access_sf()
        next
      }
    }
    f <- file.path(cache_dir, sprintf("tile_%03d_%03d.rds", i, j))
    if (file.exists(f) && !overwrite) {
      tiles_sf[[g]] <- readRDS(f)
      next
    }
    sfj <- .osm_ways_to_sf(fetch_box(tb), roads, trails)
    saveRDS(sfj, f) # persist as it completes
    tiles_sf[[g]] <- sfj
  }

  stamp <- attr(tiles_sf[[1]], "timestamp")
  allw <- do.call(rbind, tiles_sf)
  allw <- allw[!duplicated(allw$osm_id), ] # tile seams share boundary ways
  if (out_crs != sf::st_crs(4326)) {
    allw <- sf::st_transform(allw, out_crs)
  } # also sets CRS when empty
  if (!nrow(allw)) {
    warning("no highways returned for this bbox")
  }

  sf::st_write(allw, path, quiet = TRUE, delete_dsn = TRUE)
  message(sprintf("osm_access: %d ways -> %s", nrow(allw), path))
  structure(allw, timestamp = stamp, path = path)
}

# ---------------------------------------------------------------------------
# internal
# ---------------------------------------------------------------------------

# An empty access-network sf with the canonical columns (lon/lat), so empty tiles
# rbind cleanly and cache round-trips preserve schema.
.empty_access_sf <- function() {
  sf::st_sf(
    osm_id = character(0),
    highway = character(0),
    class = character(0),
    geometry = sf::st_sfc(crs = 4326)
  )
}

# Parsed Overpass JSON -> sf LINESTRINGs (0+ rows, lon/lat), carrying the OSM
# timestamp. Each way's highway tag is classed road/trail/NA against the requested
# sets. Pure (no I/O) so it is unit-testable without the Overpass round trip.
.osm_ways_to_sf <- function(j, roads, trails) {
  ways <- Filter(
    function(e) e$type == "way" && !is.null(e$geometry),
    j$elements
  )
  ts <- j$osm3s$timestamp_osm_base
  if (!length(ways)) {
    return(structure(.empty_access_sf(), timestamp = ts))
  }
  ids <- vapply(ways, function(w) as.character(w$id), "")
  geoms <- sf::st_sfc(
    lapply(ways, function(w) {
      sf::st_linestring(do.call(
        rbind,
        lapply(w$geometry, function(p) c(p$lon, p$lat))
      ))
    }),
    crs = 4326
  )
  htype <- vapply(
    ways,
    function(w) {
      if (!is.null(w$tags$highway)) w$tags$highway else NA_character_
    },
    ""
  )
  cls <- ifelse(
    htype %in% roads,
    "road",
    ifelse(htype %in% trails, "trail", NA)
  )
  structure(
    sf::st_sf(osm_id = ids, highway = htype, class = cls, geometry = geoms),
    timestamp = ts
  )
}

# GBIF occurrence table -> sf POINTs: drop rows missing coords or speciesKey, keep the
# standard columns that are present, project to out_crs. Pure (no download/write) so
# the row/column/CRS logic is unit-testable from an in-memory occurrence frame.
.gbif_occ_to_sf <- function(occ, out_crs) {
  keep <- !is.na(occ$decimalLongitude) &
    !is.na(occ$decimalLatitude) &
    !is.na(occ$speciesKey)
  cols <- intersect(
    c(
      "speciesKey",
      "species",
      "basisOfRecord",
      "coordinateUncertaintyInMeters",
      "year"
    ),
    names(occ)
  )
  res <- sf::st_as_sf(
    as.data.frame(occ[keep, c("decimalLongitude", "decimalLatitude", cols)]),
    coords = c("decimalLongitude", "decimalLatitude"),
    crs = 4326
  )
  if (out_crs != sf::st_crs(4326)) {
    res <- sf::st_transform(res, out_crs)
  }
  res
}

# Reduce an sf/terra object or a numeric vector to a lon/lat bbox + its source CRS.
.lonlat_bbox <- function(bbox) {
  if (is.numeric(bbox)) {
    stopifnot(length(bbox) == 4)
    return(list(box = as.numeric(bbox), crs = sf::st_crs(NA)))
  }
  src <- tryCatch(sf::st_crs(bbox), error = function(e) sf::st_crs(NA))
  e <- if (inherits(bbox, c("SpatRaster", "SpatVector", "SpatExtent"))) {
    ex <- terra::ext(bbox)
    as.numeric(c(ex[1], ex[3], ex[2], ex[4])) # xmin,ymin,xmax,ymax (strip ext's names)
  } else {
    as.numeric(sf::st_bbox(bbox)[c("xmin", "ymin", "xmax", "ymax")]) # name, then strip
  }
  box <- sf::st_bbox(
    c(xmin = e[1], ymin = e[2], xmax = e[3], ymax = e[4]),
    crs = src
  )
  if (!is.na(src) && src != sf::st_crs(4326)) {
    box <- sf::st_bbox(sf::st_transform(sf::st_as_sfc(box), 4326))
  }
  list(box = as.numeric(box[c("xmin", "ymin", "xmax", "ymax")]), crs = src)
}

#' Fetch an OSM network scoped to patch clusters, connected to an origin
#'
#' Pulls dense roads+trails only within boxes around each patch cluster
#' (\code{\link{cluster_patches}}), plus a \strong{roads-only} connective layer over
#' the envelope of the origin and all clusters. The field office then drives in on one
#' connected network to every cluster, without fetching the empty country between them
#' (the hard part of a scattered domain). Reuses \code{\link{osm_access}} for every
#' sub-pull, so caching, throttling and back-off all apply.
#'
#' @param patches \pkg{sf} points/polygons to scope the pull to.
#' @param origin the trip origin (field office): an \pkg{sf} point, or a numeric
#'   \code{c(lon, lat)} in EPSG:4326.
#' @param crs planar CRS (metres) to work in; defaults to the patches' CRS.
#' @param eps_km cluster join distance (km, default \code{5};
#'   see \code{\link{cluster_patches}}).
#' @param buffer_m buffer (m) added around each cluster's bounding box (default
#'   \code{1500}).
#' @param roads,trails OSM \code{highway} classes pulled densely \emph{within} cluster
#'   boxes (\code{trails} only there).
#' @param connect_roads the (major) road classes for the \emph{connective} envelope
#'   layer that links the origin to the clusters - default the through-routes
#'   \code{motorway/trunk/primary/secondary/tertiary}. Residential/service/track are
#'   left out here: they are local bloat and already come from the cluster pulls.
#' @param path GeoPackage for the merged network (\code{NULL} -> cwd).
#' @param cache_dir folder for the per-pull checkpoints (\code{NULL} -> beside
#'   \code{path}); existing pulls are reused, so the whole fetch is resumable.
#' @param tiles_connect tiles for the connective roads pull (\code{NULL} -> ~1 per
#'   30 km of envelope width).
#' @param local_tile_km target tile width (km) for each cluster's dense pull, so a big
#'   habitat block is not one enormous Overpass query (default \code{20}).
#' @param contract simplify the merged network to junction-to-junction edges before
#'   writing (default \code{TRUE}; \code{\link{contract_network}}) - the on-disk file is
#'   then the contracted version, ~30x fewer graph nodes.
#' @param ... passed to \code{\link{osm_access}} (e.g. \code{endpoint}, \code{contact},
#'   \code{pause}).
#' @return a list: \code{network} (merged \pkg{sf} lines, deduped), \code{origin}
#'   (\pkg{sf} point in \code{crs}) and \code{clusters} (centroids with \code{cluster}
#'   ids); attribute \code{path} is where the network was written. Feed
#'   \code{network} + \code{origin} to \code{\link{accessibility}}.
#' @export
osm_network_for <- function(
  patches,
  origin,
  crs = NULL,
  eps_km = 5,
  buffer_m = 1500,
  roads = c(
    "motorway",
    "trunk",
    "primary",
    "secondary",
    "tertiary",
    "unclassified",
    "residential",
    "service",
    "living_street",
    "road",
    "track"
  ),
  trails = c("path", "footway", "bridleway", "cycleway", "steps"),
  connect_roads = c("motorway", "trunk", "primary", "secondary", "tertiary"),
  path = NULL,
  cache_dir = NULL,
  tiles_connect = NULL,
  local_tile_km = 20,
  contract = TRUE,
  ...
) {
  pcrs <- if (!is.null(crs)) sf::st_crs(crs) else sf::st_crs(patches)
  patches <- sf::st_transform(patches, pcrs)
  org <- if (inherits(origin, c("sf", "sfc", "SpatVector"))) {
    sf::st_transform(sf::st_as_sf(origin), pcrs)
  } else {
    sf::st_transform(
      sf::st_as_sf(sf::st_sfc(
        sf::st_point(c(origin[1], origin[2])),
        crs = 4326
      )),
      pcrs
    )
  }

  cc <- cluster_patches(patches, eps_km = eps_km, crs = pcrs)
  boxes <- lapply(split(seq_len(nrow(cc)), cc$cluster), function(ix) {
    sf::st_buffer(sf::st_as_sfc(sf::st_bbox(cc[ix, ])), buffer_m)
  })

  if (is.null(path)) {
    path <- file.path(getwd(), "osm_network_for.gpkg")
  }
  if (is.null(cache_dir)) {
    cache_dir <- file.path(
      dirname(path),
      paste0(tools::file_path_sans_ext(basename(path)), "_cache")
    )
  }
  dir.create(cache_dir, showWarnings = FALSE, recursive = TRUE)

  # local dense pulls (roads + trails) per cluster box; tile big boxes (~1 per
  # local_tile_km) so no single Overpass query is enormous.
  locals <- lapply(seq_along(boxes), function(i) {
    bw <- as.numeric(diff(sf::st_bbox(boxes[[i]])[c("xmin", "xmax")])) / 1000
    tl <- max(1L, as.integer(ceiling(bw / local_tile_km)))
    osm_access(
      boxes[[i]],
      crs = pcrs,
      roads = roads,
      trails = trails,
      tiles = tl,
      path = file.path(cache_dir, sprintf("cluster_%03d.gpkg", i)),
      cache_dir = file.path(cache_dir, sprintf("cluster_%03d_tiles", i)),
      ...
    )
  })

  # connective roads-only pull over the {origin + clusters} envelope
  env <- sf::st_as_sfc(sf::st_bbox(do.call(
    c,
    c(list(sf::st_geometry(org)), lapply(boxes, sf::st_geometry))
  )))
  if (is.null(tiles_connect)) {
    w <- as.numeric(diff(sf::st_bbox(env)[c("xmin", "xmax")]))
    tiles_connect <- max(1L, ceiling(w / 30000))
  }
  conn <- osm_access(
    env,
    crs = pcrs,
    roads = connect_roads,
    trails = character(0),
    tiles = tiles_connect,
    exclude = do.call(c, lapply(boxes, sf::st_geometry)),
    path = file.path(cache_dir, "connect.gpkg"),
    cache_dir = file.path(cache_dir, "connect_tiles"),
    ...
  )

  net <- do.call(rbind, c(locals, list(conn)))
  net <- net[!duplicated(net$osm_id), , drop = FALSE]
  if (contract && nrow(net)) {
    # simplify to junction-to-junction edges
    net <- contract_network(net)
  }
  sf::st_write(net, path, quiet = TRUE, delete_dsn = TRUE)
  message(sprintf(
    "osm_network_for: %d %sways, %d clusters -> %s",
    nrow(net),
    if (contract) "contracted " else "",
    length(boxes),
    path
  ))
  structure(list(network = net, origin = org, clusters = cc), path = path)
}

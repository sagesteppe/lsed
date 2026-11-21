#' Patch and subpatch delineation for survey-unit mapping
#'
#' \enumerate{
#'   \item \code{\link{delineate_patches}} binarises the probability surface at a
#'     suitability threshold and runs a marker-controlled watershed (via
#'     WhiteboxTools) to break the suitable network at low necks, with a rook's-case
#'     component fallback for cells that drain off-mask, then drops sub-\code{min_area}
#'     slivers. This is the shared front end for both subdivision levers.
#'   \item \code{\link{band_subpatches}} subdivides each oversized patch: it
#'     \emph{contours} the raw surface into fixed suitability bands, finds same-band
#'     connected pieces (\pkg{igraph} components), \emph{snaps} sub-threshold pieces
#'     into their highest-band contiguous neighbour (\code{\link{snap_pieces}}), then
#'     geometrically caps any surviving unit still above the maximum size
#'     (\code{\link{kcap}}).
#' }
#'
#' \pkg{terra} + \pkg{whitebox} for the raster/watershed work, \pkg{igraph} for the
#' connected-component and region-adjacency graphs (\code{\link{rook_edges}} supplies
#' the raster edge list; the greedy band-priority merge in \code{\link{snap_pieces}}
#' is the one graph step with no library primitive.
#'

# Square metres per US survey acre -- the one area constant the pipeline uses, so
# acre<->m^2<->cell conversions all read from here rather than a scattered literal.
#' @keywords internal
M2_PER_ACRE <- 4046.856

# ---------------------------------------------------------------------------
# Stage 1: watershed -> patches
# ---------------------------------------------------------------------------

#' Delineate patches by marker-controlled watershed
#'
#' Binarise \code{pr} at \code{sens_spec}, then split the suitable network with a
#' marker-controlled watershed on the \emph{inverted} surface (high-probability cores
#' become pits; necks shallower than \code{delta} are merged by depression filling,
#' surviving pits seed the watershed). Suitable cells that drain off-mask (small
#' patches with no interior pit) keep an identity through a rook's-case (4-connected)
#' component fallback, so none are dropped. Patches at or below \code{min_area} m^2
#' are removed as un-surveyable slivers. Watershed intermediates are written to
#' \code{rdir} so a partial re-run can reuse finished steps.
#'
#' @param pr A \pkg{terra} \code{SpatRaster} of predicted probability (one layer).
#' @param sens_spec Suitable-habitat threshold in probability units; cells
#'   \code{>= sens_spec} are suitable.
#' @param delta Prominence (minimum neck depth, probability units) below which two
#'   cores are merged rather than split. Passed to \code{wbt_fill_depressions(max_depth=)}.
#' @param min_area Patches with total area at or below this (m^2) are dropped.
#' @param rdir Directory for the watershed intermediate rasters (dem/fill/sink/pntr/seg).
#'
#' @return A \code{SpatRaster} of integer patch ids (\code{NA} off-patch), aligned to \code{pr}.
#' @seealso \code{\link{band_subpatches}}
#' @keywords internal
delineate_patches <- function(pr, sens_spec, delta, min_area, rdir) {
  mask <- pr >= sens_spec

  # Hydrological inversion trick: cores -> pits, fill necks shallower than delta,
  # label surviving pits as seeds, route every suitable cell to the core it drains to.
  dem <- terra::ifel(mask, 1 - pr, NA)
  terra::writeRaster(dem, file.path(rdir, "patch-dem.tif"), overwrite = TRUE)
  whitebox::wbt_fill_depressions(
    file.path(rdir, "patch-dem.tif"),
    file.path(rdir, "patch-fill.tif"),
    max_depth = delta
  )
  whitebox::wbt_sink(
    file.path(rdir, "patch-fill.tif"),
    file.path(rdir, "patch-sink.tif"),
    zero_background = TRUE
  )
  whitebox::wbt_d8_pointer(
    file.path(rdir, "patch-fill.tif"),
    file.path(rdir, "patch-pntr.tif")
  )
  whitebox::wbt_watershed(
    file.path(rdir, "patch-pntr.tif"),
    file.path(rdir, "patch-sink.tif"),
    file.path(rdir, "patch-seg.tif")
  )

  seg <- terra::rast(file.path(rdir, "patch-seg.tif"))
  patch_id <- merge_offmask(seg, mask)

  drop_slivers(patch_id, min_area)
}

#' Reconcile watershed labels with off-mask suitable cells
#'
#' Post-watershed assembly: take the raw watershed segmentation \code{seg} and the
#' suitability \code{mask}, drop the watershed's zero/negative background, and give an
#' identity to suitable cells the watershed left unlabelled (those that drained
#' off-mask, i.e. small patches with no interior pit) via a rook's-case (4-connected)
#' component pass. Those fallback component ids are shifted above the maximum watershed
#' label so the two id spaces never collide, then layered under the watershed labels
#' with \code{terra::cover} and clipped back to the mask.
#'
#' @param seg A \code{SpatRaster} of raw watershed segment labels (0/negative =
#'   background).
#' @param mask A logical \code{SpatRaster}: \code{TRUE} on suitable cells.
#' @return A \code{SpatRaster} of integer patch ids (\code{NA} off-mask), before the
#'   sliver filter.
#' @seealso \code{\link{delineate_patches}}, \code{\link{drop_slivers}}
#' @keywords internal
merge_offmask <- function(seg, mask) {
  seg[seg <= 0] <- NA

  # Fallback for suitable cells that drain off-mask: rook's-case components, id-shifted
  # above the watershed labels so the two id spaces never collide.
  unlab <- mask & is.na(seg)
  cc <- terra::patches(
    terra::ifel(unlab, 1, NA),
    directions = 4,
    zeroAsNA = TRUE
  ) +
    terra::global(seg, "max", na.rm = TRUE)[[1]]
  terra::mask(terra::cover(seg, cc), mask, maskvalues = c(NA, 0))
}

#' Drop patches below a minimum area
#'
#' Remove patches whose total area (cell count times cell area) is at or below
#' \code{min_area} m^2, as un-surveyable slivers. The surviving patch ids keep their
#' original values (ids are \emph{not} renumbered), so an id-space built upstream
#' stays valid.
#'
#' @param patch_id A \code{SpatRaster} of integer patch ids (\code{NA} off-patch).
#' @param min_area Patches with total area at or below this (m^2) are dropped.
#' @return \code{patch_id} with the sliver patches set to \code{NA}.
#' @seealso \code{\link{delineate_patches}}
#' @keywords internal
drop_slivers <- function(patch_id, min_area) {
  cell_area <- prod(terra::res(patch_id))
  fr <- terra::freq(patch_id)
  drop_ids <- fr$value[fr$count * cell_area <= min_area]
  drop_ids <- drop_ids[!is.na(drop_ids)]
  # No slivers (every patch already exceeds min_area): nothing to do, and
  # terra::subst() errors on an empty `from`, so return the raster unchanged.
  if (!length(drop_ids)) {
    return(patch_id)
  }
  # terra::subst, not `%in%`: `%in%` is not a primitive, so it would not S4-dispatch
  # to terra here (terra is imported, not attached) and would fall back to the base
  # method, returning a plain logical that terra::ifel then rejects.
  terra::subst(patch_id, drop_ids, NA)
}

# ---------------------------------------------------------------------------
# Low-level helpers: adjacency, components, snap/merge, geometric cap
# ---------------------------------------------------------------------------

#' Rook's-case adjacency among a set of raster cells
#'
#' East/south neighbour edges among a set of global cell indices, returned as local
#' index pairs (positions within \code{gc}). East+south only, since each undirected
#' rook edge is counted once from its lower-index endpoint.
#'
#' @param gc Integer vector of global (1-based) cell indices.
#' @param nc,nr Number of columns and rows in the parent raster.
#' @return A list with integer vectors \code{i} and \code{j}: local index pairs of adjacent cells.
#' @keywords internal
rook_edges <- function(gc, nc, nr) {
  r <- (gc - 1L) %/% nc
  cc <- (gc - 1L) %% nc
  eE <- gc[cc < nc - 1L]
  jE <- match(eE + 1L, gc)
  okE <- !is.na(jE)
  eS <- gc[r < nr - 1L]
  jS <- match(eS + nc, gc)
  okS <- !is.na(jS)
  list(i = c(match(eE[okE], gc), match(eS[okS], gc)), j = c(jE[okE], jS[okS]))
}

#' Connected components of a cell set from an edge subset
#'
#' Thin wrapper over \code{\link[igraph]{components}}: label \code{n} nodes
#' \code{1..m} by connected component given an undirected edge subset. Isolated nodes
#' (no edge) each get their own label. Labels are re-mapped to \strong{first-appearance
#' order} (node 1's component is 1, the next new component is 2, ...) so the output is
#' deterministic and independent of igraph's internal traversal order -- this keeps the
#' downstream unit numbering (and k-means-cap seed draws) stable across igraph versions.
#'
#' @param n Number of nodes.
#' @param ei,ej Integer vectors of equal length: the endpoints (node indices) of each edge.
#' @return Integer vector of length \code{n} with component labels \code{1..m}.
#' @keywords internal
comp_labels <- function(n, ei, ej) {
  g <- igraph::make_graph(as.vector(rbind(ei, ej)), n = n, directed = FALSE)
  m <- igraph::components(g)$membership
  match(m, unique(m))
}

#' Snap sub-threshold band-pieces into their best contiguous neighbour
#'
#' Sequential snap/merge over a region-adjacency graph: repeatedly absorb each piece
#' whose (accumulated) area is below its band's floor into its contiguous neighbour,
#' preferring the highest band and then the largest area. The floor
#' \code{minac[band]} \strong{tightens as suitability rises}, so small high-value
#' ridge units survive while broad low aprons are cleaned of slivers. Passes repeat
#' until a pass makes no merges (or \code{npass} is reached), letting chains collapse.
#'
#' @param piece Integer vector (length = n cells) of band-piece labels \code{1..np}
#'   (e.g. from \code{\link{comp_labels}} on same-band edges).
#' @param ei,ej Integer vectors: \emph{all} rook edges as local cell-index pairs
#'   (from \code{\link{rook_edges}}); cross-piece edges define adjacency.
#' @param area Numeric vector (length \code{np}) of per-piece area (acres).
#' @param band Integer vector (length \code{np}) of per-piece band (1 low .. high).
#' @param minac Numeric vector of per-band minimum size (acres); a piece whose area
#'   is below \code{minac[band]} is a merge candidate.
#' @param npass Maximum number of snap passes.
#' @return Integer vector of length \code{np}: the resolved root piece for each piece.
#'   Map per-cell with \code{root[piece]}.
#' @keywords internal
snap_pieces <- function(piece, ei, ej, area, band, minac, npass = 3L) {
  np <- length(area)

  # Region-adjacency graph (igraph): one node per piece, an edge wherever two pieces
  # touch. simplify() drops the duplicate edges from multiple shared cell borders;
  # as_adj_list gives the per-piece neighbour vectors the snap loop walks.
  dif <- piece[ei] != piece[ej]
  g <- igraph::make_graph(
    as.vector(rbind(piece[ei[dif]], piece[ej[dif]])),
    n = np,
    directed = FALSE
  )
  adj <- lapply(
    igraph::as_adj_list(igraph::simplify(g), mode = "all"),
    as.integer
  )

  parent <- seq_len(np)
  arr <- area
  brr <- band
  find <- function(x) {
    while (parent[x] != x) {
      parent[x] <<- parent[parent[x]]
      x <- parent[x]
    }
    x
  }
  for (pass in seq_len(npass)) {
    did <- 0L
    for (p in order(arr)) {
      rp <- find(p)
      if (arr[rp] >= minac[brr[rp]]) {
        next
      }
      nb <- adj[[p]]
      if (!length(nb)) {
        next
      }
      rr <- unique(vapply(nb, find, integer(1)))
      rr <- rr[rr != rp]
      if (!length(rr)) {
        next
      }
      tgt <- rr[order(-brr[rr], -arr[rr])][1]
      parent[rp] <- tgt
      arr[tgt] <- arr[tgt] + arr[rp]
      did <- did + 1L
    }
    if (did == 0L) break
  }
  vapply(seq_len(np), find, integer(1))
}

#' Geometric k-means cap on a cell set
#'
#' Split a set of cells into \code{ceil(n / capn)} compact pieces, each at or below
#' \code{capn} cells, by k-means on cell (col, row) positions; \code{k} is bumped up
#' until no cluster exceeds the cap (k-means targets equal sizes but does not bound
#' them). Sets under the cap pass through as a single piece.
#'
#' @param gc Integer vector of global (1-based) cell indices.
#' @param capn Maximum pieces size in cells.
#' @param nc Number of columns in the parent raster (to recover col/row from \code{gc}).
#' @return Integer cluster label per cell (all \code{1L} when \code{n <= capn}).
#' @keywords internal
kcap <- function(gc, capn, nc) {
  n <- length(gc)
  if (n <= capn) {
    return(rep(1L, n))
  }
  xy <- cbind((gc - 1L) %% nc, (gc - 1L) %/% nc)
  k <- as.integer(ceiling(n / capn))
  repeat {
    km <- stats::kmeans(xy, centers = k, iter.max = 100)
    if (max(tabulate(km$cluster)) <= capn) {
      break
    }
    k <- k + 1L
  }
  km$cluster
}

# ---------------------------------------------------------------------------
# Stage 2: contour (band) -> snap -> k-means cap
# ---------------------------------------------------------------------------

#' Apply a per-patch function over patch groups, optionally in parallel
#'
#' Runs \code{fn} over the elements of \code{groups} (one per patch) with
#' \code{\link[parallel]{mclapply}} when \code{cores > 1}, else \code{lapply}.
#' mclapply forks (copy-on-write), so the big shared vectors are not serialised;
#' on Windows \code{cores > 1} degrades to serial automatically. Output order
#' always matches input order, so results stay deterministic regardless of cores.
#'
#' @param groups A list (e.g. from \code{split}) of per-patch cell positions.
#' @param fn A function of one group element returning that patch's local labels.
#' @param cores Integer worker count (\code{1} = serial).
#' @return A list the same length/order as \code{groups}.
#' @keywords internal
papply <- function(groups, fn, cores = 1) {
  if (cores > 1L) {
    res <- parallel::mclapply(groups, fn, mc.cores = cores)
    bad <- vapply(res, inherits, logical(1), "try-error")
    if (any(bad)) {
      stop(
        "parallel subdivision failed in ",
        sum(bad),
        " patch(es): ",
        conditionMessage(attr(res[[which(bad)[1]]], "condition"))
      )
    }
    res
  } else {
    lapply(groups, fn)
  }
}

#' Stitch per-patch local unit labels into one globally-numbered vector
#'
#' Each patch's worker returns labels \code{1..k_i} local to that patch; this
#' offsets them by the running total so the final ids are \code{1..N} in patch
#' order -- identical whatever order the workers finished in.
#'
#' @param groups List of per-patch cell positions (as passed to \code{\link{papply}}).
#' @param labs List of per-patch local label vectors (from \code{\link{papply}}).
#' @param n Length of the output (number of suitable cells).
#' @return Integer vector of global unit ids, length \code{n}.
#' @keywords internal
stitch_units <- function(groups, labs, n) {
  unit <- integer(n)
  off <- 0L
  for (i in seq_along(groups)) {
    unit[groups[[i]]] <- labs[[i]] + off
    off <- off + max(labs[[i]])
  }
  unit
}

#' Subdivide oversized patches by suitability banding
#'
#' For each patch larger than \code{trig_ac} acres: cut cells into fixed suitability
#' \emph{bands} on the raw surface, find same-band connected pieces, snap
#' sub-threshold pieces into their highest-band contiguous neighbour
#' (\code{\link{snap_pieces}}), then geometrically cap any surviving unit above
#' \code{cap_cells} (\code{\link{kcap}}). Patches at or below \code{trig_ac} pass
#' through as a single unit. Units are numbered sequentially across all patches.
#'
#' @param cells Integer vector of the global cell indices of all suitable cells
#'   (i.e. \code{which(!is.na(values(patch_id)))}).
#' @param memb Integer vector (same length as \code{cells}) of the parent patch id
#'   per suitable cell.
#' @param pval Numeric vector of probability values at the suitable cells,
#'   \strong{aligned to \code{cells}} (i.e. \code{pr[cells][, 1]}), not the whole
#'   surface. Reading only these cells avoids materialising the full raster.
#' @param nc,nr Columns and rows of the parent raster.
#' @param cell_area Area of one cell (m^2).
#' @param band_brks Numeric band edges on the raw surface (length = n bands + 1),
#'   passed to \code{cut(right = FALSE)}.
#' @param band_minac Numeric per-band minimum size (acres) for \code{\link{snap_pieces}}.
#' @param trig_ac Only patches larger than this (acres) are banded.
#' @param cap_cells Maximum final unit size in cells (geometric cap).
#' @param seed Base random seed. Each patch is seeded \code{seed + patch id}, so its
#'   split is reproducible and \strong{independent of patch order / core count}.
#' @param cores Integer worker count for \code{\link{papply}} (\code{1} = serial).
#' @return Integer vector (same length as \code{cells}) of subpatch unit ids.
#' @seealso \code{\link{delineate_patches}}, \code{\link{snap_pieces}}, \code{\link{kcap}}
#' @keywords internal
band_subpatches <- function(
  cells,
  memb,
  pval,
  nc,
  nr,
  cell_area,
  band_brks,
  band_minac,
  trig_ac,
  cap_cells,
  seed = 1,
  cores = 1
) {
  # Each patch is independent: label its cells 1..k locally, then stitch globally.
  groups <- split(seq_along(memb), memb)

  one_patch <- function(sel) {
    gc <- cells[sel]

    # Small patch -> one survey unit, untouched (no RNG used).
    if (length(gc) * cell_area / M2_PER_ACRE <= trig_ac) {
      return(rep(1L, length(gc)))
    }

    set.seed(seed + memb[sel[1]]) # deterministic per-patch seed (order-independent)

    # Contour into bands, then same-band connected pieces (pval[sel] = this patch's probs).
    vb <- as.integer(cut(pval[sel], band_brks, right = FALSE))
    E <- rook_edges(gc, nc, nr)
    ei <- E$i
    ej <- E$j
    same <- vb[ei] == vb[ej]
    piece <- comp_labels(length(gc), ei[same], ej[same])
    np <- max(piece)
    pband <- vb[match(seq_len(np), piece)] # band of each piece (constant within a piece)
    parea <- as.numeric(tabulate(piece)) * cell_area / M2_PER_ACRE

    # Snap sub-threshold pieces into their best neighbour, then geometrically cap.
    uroot <- snap_pieces(piece, ei, ej, parea, pband, band_minac)[piece]
    out <- integer(length(gc))
    k <- 0L
    for (u in unique(uroot)) {
      iu <- which(uroot == u)
      if (length(iu) <= cap_cells) {
        k <- k + 1L
        out[iu] <- k
      } else {
        cl <- kcap(gc[iu], cap_cells, nc)
        for (c in unique(cl)) {
          k <- k + 1L
          out[iu[cl == c]] <- k
        }
      }
    }
    out
  }

  stitch_units(groups, papply(groups, one_patch, cores), length(cells))
}

#' Subdivide oversized patches by a compact geometric cap (k-means lever)
#'
#' The simpler alternative to \code{\link{band_subpatches}}: ignore suitability and
#' split each patch purely on geometry. A patch at or below the cap passes through as
#' one unit; a larger one is cut into \code{ceil(area / cap)} compact k-means pieces,
#' each at or below \code{max_area_ac} acres (\code{\link{kcap}}). Units are numbered
#' sequentially across patches. Compact partitions, not watersheds -- a concave patch
#' can yield a unit in disjoint pieces.
#'
#' @param cells Integer vector of the global cell indices of all suitable cells.
#' @param memb Integer vector (same length as \code{cells}) of parent patch id per cell.
#' @param nc Number of columns in the parent raster (for col/row recovery in \code{\link{kcap}}).
#' @param cell_area Area of one cell (m^2).
#' @param max_area_ac Maximum unit size (acres).
#' @param seed Base random seed; each patch is seeded \code{seed + patch id} so its
#'   split is reproducible and independent of patch order / core count.
#' @param cores Integer worker count for \code{\link{papply}} (\code{1} = serial).
#' @return Integer vector (same length as \code{cells}) of subpatch unit ids.
#' @seealso \code{\link{band_subpatches}}, \code{\link{kcap}}
#' @keywords internal
cap_subpatches <- function(
  cells,
  memb,
  nc,
  cell_area,
  max_area_ac,
  seed = 1,
  cores = 1
) {
  cap_cells <- floor(max_area_ac * M2_PER_ACRE / cell_area)
  groups <- split(seq_along(memb), memb)
  one_patch <- function(sel) {
    set.seed(seed + memb[sel[1]]) # deterministic per-patch seed
    kcap(cells[sel], cap_cells, nc) # rep(1L, .) when already under the cap
  }
  stitch_units(groups, papply(groups, one_patch, cores), length(cells))
}

# ---------------------------------------------------------------------------
# Attribute helpers (DRY: used for patches and for both subpatch levers)
# ---------------------------------------------------------------------------

#' Per-group probability summary (min / max / mean / n) from cell values
#'
#' Grouped reduction over the per-cell probability values, returning the minimum,
#' maximum, \strong{mean}, and cell count per group in one pass. The mean is the plain
#' unweighted cell mean -- identical to \code{terra::zonal(pr, id, "mean")} (terra's
#' zonal mean is unweighted, and the grid is equal-area, so this is also the
#' area-weighted mean) -- but it is computed here directly from the values we already
#' hold alongside min and max, with no extra raster pass.
#'
#' @param val Numeric vector of per-cell probabilities.
#' @param grp Integer vector (same length) of group ids (unit or patch).
#' @return A data.frame with columns \code{id, prob_min, prob_max, prob_mean, n},
#'   one row per group, ordered by ascending id.
#' @keywords internal
unit_prob <- function(val, grp) {
  s <- split(val, grp) # keyed by sorted unique grp
  data.frame(
    id = as.integer(names(s)),
    prob_min = vapply(s, min, numeric(1)),
    prob_max = vapply(s, max, numeric(1)),
    prob_mean = vapply(s, mean, numeric(1)),
    n = lengths(s),
    row.names = NULL
  )
}

#' Roll per-unit stats up to their parent patch
#'
#' Aggregate the per-unit attribute table to one row per parent patch. Patch stats
#' are exact aggregates of their units' --- min of the mins, max of the maxes,
#' n-weighted mean of the means, summed cell count --- so an un-split patch (a single
#' unit) is a straight copy and no patch is re-reduced from the cell values a second
#' time. Acreage is recomputed from the summed cell count.
#'
#' @param ap A per-unit data.frame with (at least) columns \code{patch}, \code{n},
#'   \code{prob_min}, \code{prob_max}, \code{prob_mean} (e.g. the units table built
#'   in \code{\link{survey_units}}).
#' @param cell_area Area of one cell (m^2).
#' @return A data.frame with columns \code{patch, prob_min, prob_max, prob_mean, n,
#'   acres}, one row per patch, ordered by ascending patch id.
#' @keywords internal
rollup_patches <- function(ap, cell_area) {
  g <- ap$patch
  pn <- tapply(ap$n, g, sum)
  pp <- data.frame(
    patch = as.integer(names(pn)),
    prob_min = as.numeric(tapply(ap$prob_min, g, min)),
    prob_max = as.numeric(tapply(ap$prob_max, g, max)),
    prob_mean = as.numeric(tapply(ap$prob_mean * ap$n, g, sum)) /
      as.numeric(pn),
    n = as.numeric(pn),
    row.names = NULL
  )
  pp$acres <- pp$n * cell_area / M2_PER_ACRE
  pp
}

#' Scatter a per-suitable-cell label vector back into a raster
#'
#' Build a \code{SpatRaster} aligned to \code{template}, with \code{vals} written at
#' \code{cells} and \code{NA} everywhere else.
#'
#' @param template A \code{SpatRaster} whose geometry the result copies.
#' @param cells Integer global cell indices to fill.
#' @param vals Integer labels (same length as \code{cells}).
#' @param name Layer name for the result.
#' @return A single-layer integer \code{SpatRaster}.
#' @keywords internal
labels_to_raster <- function(template, cells, vals, name = "unit") {
  r <- terra::rast(template)
  v <- rep(NA_integer_, terra::ncell(template))
  v[cells] <- as.integer(vals)
  terra::values(r) <- v
  names(r) <- name
  r
}

#' Majority-rule area-of-applicability fraction per region
#'
#' Fraction of each region's cells that are in-domain (dissimilarity index
#' \code{<= aoa_thresh}); used with a 0.5 cut for a majority IN/OUT tag.
#'
#' @param di A \code{SpatRaster} of the AOA dissimilarity index.
#' @param id_rast A \code{SpatRaster} of integer region ids.
#' @param aoa_thresh In-domain threshold (DI normalised to 1 by default).
#' @return A data.frame \code{id, frac_in_aoa}.
#' @keywords internal
aoa_fraction <- function(di, id_rast, aoa_thresh = 1) {
  fr <- terra::zonal(di <= aoa_thresh, id_rast, fun = "mean", na.rm = TRUE)
  stats::setNames(fr, c("id", "frac_in_aoa"))
}

#' Crop a raster to the bounding box of a cell set
#'
#' \code{terra::as.polygons} scans the whole grid, so its cost tracks the raster
#' \emph{extent}, not the number of data cells. When the data is spatially localised,
#' cropping to its bounding box first is a large speed-up; when it spans the whole
#' extent, cropping only adds overhead. The bounding box is computed arithmetically
#' from \code{cells} (no raster scan), and the crop is skipped unless the box is
#' smaller than \code{frac} of the full extent, so it never hurts.
#'
#' @param x A \code{SpatRaster}.
#' @param cells Integer global cell indices of the data cells.
#' @param frac Crop only when the data bounding box is below this fraction of the
#'   full extent (default 0.5).
#' @return \code{x} cropped to the data bounding box, or \code{x} unchanged.
#' @keywords internal
crop_to_cells <- function(x, cells, frac = 0.5) {
  ncx <- terra::ncol(x)
  nrx <- terra::nrow(x)
  rr <- (cells - 1L) %/% ncx
  cc <- (cells - 1L) %% ncx
  r0 <- min(rr)
  r1 <- max(rr)
  c0 <- min(cc)
  c1 <- max(cc)
  if ((r1 - r0 + 1) * (c1 - c0 + 1) >= frac * as.double(nrx) * ncx) {
    return(x)
  }
  xr <- terra::xres(x)
  yr <- terra::yres(x)
  e <- terra::ext(
    terra::xmin(x) + c0 * xr,
    terra::xmin(x) + (c1 + 1) * xr,
    terra::ymax(x) - (r1 + 1) * yr,
    terra::ymax(x) - r0 * yr
  )
  terra::crop(x, e)
}

#' Dissolve a label raster to polygons and attach attributes
#'
#' Polygonise \code{id_rast} (one feature per id) and left-join \code{attrs} on the id
#' field. The id column of \code{attrs} must share the raster's layer name.
#'
#' @param id_rast A \code{SpatRaster} of integer region ids.
#' @param attrs A data.frame of per-id attributes whose first/key column matches
#'   \code{names(id_rast)[1]}.
#' @return A \code{SpatVector} of polygons with the attributes merged in.
#' @keywords internal
polygonize_units <- function(id_rast, attrs) {
  p <- terra::as.polygons(id_rast, dissolve = TRUE)
  # terra::merge, not bare merge(): merge is not a primitive, so here (terra imported,
  # not attached) a bare call dispatches to base::merge, which drops the geometry and
  # returns a plain data.frame.
  terra::merge(p, attrs, by = names(p)[1])
}

# ---------------------------------------------------------------------------
# Main wrapper: run the whole pipeline from arguments
# ---------------------------------------------------------------------------

#' Delineate survey units end to end
#'
#' One call runs the whole pipeline: \strong{watershed -> patches -> subdivide ->
#' attributes -> polygons}. It binarises and delineates patches
#' (\code{\link{delineate_patches}}), subdivides each oversized patch by the chosen
#' lever (\code{method = "band"} -> \code{\link{band_subpatches}};
#' \code{method = "kmeans"} -> \code{\link{cap_subpatches}}), scores per-unit and
#' per-patch probability (\code{\link{unit_prob}}), occupancy (a single point overlay),
#' acreage, priority band, and optional AOA tag, and returns both the patch- and
#' unit-level results plus a one-row summary. Only the \strong{suitable} cells are
#' ever read into memory (via \code{terra::cells} + indexed reads), so peak memory
#' scales with the suitable set, not the landscape.
#'
#' Heavy steps are memoised when \code{cache_dir} is set: the patch raster, the unit
#' raster, and (when \code{out_gpkg} is given) the polygons are reused unless a
#' signature of the inputs changes.
#'
#' @param pr Probability surface: a \code{SpatRaster} or a path to one.
#' @param occ_pts Occurrence points: a \code{SpatVector} or a path to one (same CRS as \code{pr}).
#' @param method Subdivision lever: \code{"band"} (suitability banding) or \code{"kmeans"} (geometric cap).
#' @param sens_spec,delta,min_area Patch delineation thresholds (see \code{\link{delineate_patches}}).
#' @param band_brks,band_minac,trig_ac,maxcap_ac Banding-lever parameters (see \code{\link{band_subpatches}}).
#' @param max_area_ac k-means-lever cap in acres (see \code{\link{cap_subpatches}}).
#' @param aoa_di Optional DI surface (\code{SpatRaster} or path) for the AOA tag; \code{NULL} to skip.
#' @param aoa_thresh In-domain DI threshold.
#' @param work_dir Directory for the watershed intermediate rasters (defaults to a temp dir).
#' @param cache_dir Optional directory to memoise the patch/unit rasters; \code{NULL} disables.
#' @param out_gpkg Optional path to write (and cache) the unit polygons.
#' @param seed Base random seed for the k-means steps (applied per patch; see
#'   \code{\link{band_subpatches}}).
#' @param cores Integer worker count for the per-patch subdivision (\code{1} = serial).
#'   Output is identical for any core count, so \code{cores} only affects speed, not
#'   the result or the cache. Forks via \pkg{parallel}; serial on Windows.
#' @return A list: \code{patch_raster}, \code{unit_raster} (\code{SpatRaster}s);
#'   \code{patches}, \code{units} (per-patch and per-unit attribute tables);
#'   \code{polygons} (unit \code{SpatVector}); and \code{summary} (one-row data.frame).
#' @seealso \code{\link{delineate_patches}}, \code{\link{band_subpatches}}, \code{\link{cap_subpatches}}
#' @export
survey_units <- function(
  pr,
  occ_pts,
  method = c("band", "kmeans"),
  sens_spec = 0.45,
  delta = 0.05,
  min_area = 300,
  band_brks = c(0.45, 0.55, 0.7, 0.85, 1.0001),
  band_minac = c(2, 1, 0.5, 0),
  trig_ac = 20,
  maxcap_ac = 20,
  max_area_ac = 10,
  aoa_di = NULL,
  aoa_thresh = 1,
  work_dir = tempdir(),
  cache_dir = NULL,
  out_gpkg = NULL,
  seed = 1,
  cores = 1
) {
  method <- match.arg(method)
  if (is.character(pr)) {
    pr <- terra::rast(pr)
  }
  if (is.character(occ_pts)) {
    occ_pts <- terra::vect(occ_pts)
  }
  cd <- function(f) if (is.null(cache_dir)) NULL else file.path(cache_dir, f)

  # signature of the patch stage (thresholds + source identity)
  src <- terra::sources(pr)
  base_sig <- paste(sens_spec, delta, min_area, sep = "|")
  if (length(src) && nzchar(src[1])) {
    base_sig <- paste(
      base_sig,
      basename(src[1]),
      file.info(src[1])$size,
      sep = "|"
    )
  }

  # --- Stage 1: patches (cached) ---------------------------------------------
  patch_id <- cache_rast(
    cd("patches.tif"),
    cd("patches.sig"),
    base_sig,
    function() delineate_patches(pr, sens_spec, delta, min_area, work_dir)
  )
  names(patch_id) <- "patch"

  nc <- terra::ncol(patch_id)
  nr <- terra::nrow(patch_id)
  cell_area <- prod(terra::res(patch_id))

  # suitable cells only: never materialise the full surface
  cells <- terra::cells(patch_id)
  memb <- patch_id[cells][, 1]
  pval <- pr[cells][, 1]

  # --- Stage 2: subdivide (cached) -------------------------------------------
  # "subdiv2" tags the per-patch-seed scheme so caches from the old global-seed
  # scheme invalidate. cores is NOT in the signature: output is identical for any
  # core count, so switching cores reuses the cache.
  usig <- paste(
    base_sig,
    "subdiv2",
    method,
    seed,
    if (method == "band") {
      paste(
        paste(band_brks, collapse = ","),
        paste(band_minac, collapse = ","),
        trig_ac,
        maxcap_ac,
        sep = "|"
      )
    } else {
      max_area_ac
    },
    sep = "|"
  )
  unit_rast <- cache_rast(
    cd(paste0("units_", method, ".tif")),
    cd(paste0("units_", method, ".sig")),
    usig,
    function() {
      u <- if (method == "band") {
        cap_cells <- floor(maxcap_ac * M2_PER_ACRE / cell_area)
        band_subpatches(
          cells,
          memb,
          pval,
          nc,
          nr,
          cell_area,
          band_brks,
          band_minac,
          trig_ac,
          cap_cells,
          seed,
          cores
        )
      } else {
        cap_subpatches(cells, memb, nc, cell_area, max_area_ac, seed, cores)
      }
      labels_to_raster(patch_id, cells, u, "unit")
    }
  )
  names(unit_rast) <- "unit"
  unit <- unit_rast[cells][, 1]
  nu <- max(unit)

  # --- Unit attributes (from the in-memory vectors; no extra raster scans) ---
  ap <- unit_prob(pval, unit)
  names(ap)[1] <- "unit"
  ap$patch <- memb[match(ap$unit, unit)] # parent patch (constant within unit)
  ap$acres <- ap$n * cell_area / M2_PER_ACRE
  if (method == "band") {
    ap$band <- as.integer(cut(ap$prob_max, band_brks, right = FALSE))
  }
  if (!is.null(aoa_di)) {
    if (is.character(aoa_di)) {
      aoa_di <- terra::rast(aoa_di)
    }
    fr <- aoa_fraction(aoa_di, unit_rast, aoa_thresh)
    ap$frac_in_aoa <- fr$frac_in_aoa[match(ap$unit, fr$id)]
    ap$in_aoa <- ap$frac_in_aoa > 0.5
  } else {
    ap$frac_in_aoa <- NA_real_
    ap$in_aoa <- NA
  }

  # --- Patch-level table: roll the unit stats up to their parent patch -------
  pp <- rollup_patches(ap, cell_area)

  # --- Occupancy: one point overlay on the unit raster --------------------
  # units and patches share the exact suitable footprint, so this single extract
  # gives occupied units, occupied patches (via parent), and the off-patch counts.
  uhit <- terra::extract(unit_rast, occ_pts)[, 2]
  occ_u <- sort(unique(uhit[!is.na(uhit)]))
  occ_p <- sort(unique(ap$patch[match(occ_u, ap$unit)]))
  ap$occupied <- ap$unit %in% occ_u
  pp$occupied <- pp$patch %in% occ_p
  n_points <- length(uhit)
  n_points_off <- sum(is.na(uhit)) # presences off every patch

  # --- Polygons (cached when out_gpkg is given) ------------------------------
  gsigp <- if (!is.null(out_gpkg)) paste0(out_gpkg, ".sig") else NULL
  if (
    !is.null(out_gpkg) &&
      file.exists(out_gpkg) &&
      file.exists(gsigp) &&
      identical(readLines(gsigp, warn = FALSE), usig)
  ) {
    polys <- terra::vect(out_gpkg)
  } else {
    # as.polygons is extent-bound; crop to the data bbox first when it shrinks things.
    polys <- polygonize_units(crop_to_cells(unit_rast, cells), ap)
    if (!is.null(out_gpkg)) {
      terra::writeVector(polys, out_gpkg, overwrite = TRUE)
      writeLines(usig, gsigp)
    }
  }

  summary <- data.frame(
    method = method,
    sens_spec = sens_spec,
    delta = delta,
    min_area = min_area,
    n_patches = nrow(pp),
    n_patches_occ = length(occ_p),
    n_points = n_points,
    n_points_off = n_points_off,
    n_units = nu,
    n_units_occ = sum(ap$occupied),
    n_split = sum(table(ap$patch) > 1),
    max_acres = round(max(ap$acres), 1),
    n_high = if (method == "band") sum(ap$band >= 3L) else NA_integer_,
    n_in_aoa = if (is.null(aoa_di)) {
      NA_integer_
    } else {
      sum(ap$in_aoa, na.rm = TRUE)
    }
  )

  list(
    patch_raster = patch_id,
    unit_raster = unit_rast,
    patches = pp,
    units = ap,
    polygons = polys,
    summary = summary
  )
}

#' Read a cached raster when its signature matches, else compute and cache it
#'
#' Internal memoiser: returns \code{terra::rast(tif)} when \code{tif}/\code{sigp} exist
#' and \code{sigp} holds \code{sig}; otherwise runs \code{fun()}, writes the result and
#' the signature (when \code{tif} is non-\code{NULL}), and returns it. A \code{NULL}
#' \code{tif} disables caching (always computes).
#'
#' @param tif,sigp Raster and signature sidecar paths, or \code{NULL} to skip caching.
#' @param sig Signature string recording the inputs.
#' @param fun Zero-arg function producing the \code{SpatRaster}.
#' @return The \code{SpatRaster}.
#' @keywords internal
cache_rast <- function(tif, sigp, sig, fun) {
  if (
    !is.null(tif) &&
      file.exists(tif) &&
      file.exists(sigp) &&
      identical(readLines(sigp, warn = FALSE), sig)
  ) {
    return(terra::rast(tif))
  }
  r <- fun()
  if (!is.null(tif)) {
    terra::writeRaster(r, tif, overwrite = TRUE)
    writeLines(sig, sigp)
  }
  r
}

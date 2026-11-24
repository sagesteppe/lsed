# Tests for the patch / survey-unit delineation pipeline (fn_patches.R).
#
# The pure vector helpers (adjacency, components, snap/merge, geometric cap, the
# stitch/attribute reducers, and both subdivide levers) run with no raster backend,
# so they are tested directly. The terra- and WhiteboxTools-dependent pieces are
# gated behind skips so the suite still runs on a machine without them.

skip_if_no_wbt <- function() {
  skip_if_not_installed("whitebox")
  # WhiteboxTools is an external binary that shells out a subprocess and writes a
  # GeoTIFF per step; under rapid repeated invocation it intermittently panics on its
  # own fill/sink/watershed I/O. These end-to-end pipeline tests are therefore opt-in
  # so the default suite stays deterministic -- run them with LSED_TEST_WBT=true.
  skip_if_not(
    tolower(Sys.getenv("LSED_TEST_WBT", "")) %in% c("1", "true", "yes"),
    "WhiteboxTools pipeline tests are opt-in (set LSED_TEST_WBT=true)"
  )
  ok <- tryCatch(
    file.exists(whitebox::wbt_exe_path(shell_quote = FALSE)),
    error = function(e) FALSE
  )
  skip_if_not(isTRUE(ok), "WhiteboxTools binary not available")
}

# A small grid helper: global (1-based) cell index of 0-based (row, col), matching
# the row-major convention the functions use (idx = row * nc + col + 1).
cell_of <- function(row, col, nc) row * nc + col + 1L

# ---------------------------------------------------------------------------
# rook_edges
# ---------------------------------------------------------------------------

test_that("rook_edges returns the four east/south edges of a full 2x2 grid", {
  E <- lsed:::rook_edges(1:4, nc = 2, nr = 2)
  # undirected pairs, as a sorted set of "lo-hi" strings
  pairs <- sort(apply(
    cbind(pmin(E$i, E$j), pmax(E$i, E$j)),
    1,
    paste,
    collapse = "-"
  ))
  expect_equal(pairs, c("1-2", "1-3", "2-4", "3-4"))
})

test_that("rook_edges drops edges to cells absent from the set (a hole)", {
  # 2x2 grid missing cell 3: the 1-3 (south) edge must not appear.
  E <- lsed:::rook_edges(c(1L, 2L, 4L), nc = 2, nr = 2)
  pairs <- sort(apply(
    cbind(pmin(E$i, E$j), pmax(E$i, E$j)),
    1,
    paste,
    collapse = "-"
  ))
  # local indices into c(1,2,4): 1=cell1, 2=cell2, 3=cell4
  expect_equal(pairs, c("1-2", "2-3"))
})

test_that("rook_edges on a single cell yields no edges", {
  E <- lsed:::rook_edges(1L, nc = 3, nr = 3)
  expect_length(E$i, 0)
  expect_length(E$j, 0)
})

# ---------------------------------------------------------------------------
# comp_labels
# ---------------------------------------------------------------------------

test_that("comp_labels labels components in first-appearance order", {
  # nodes 1..4, single edge 1-2 => {1,2}, {3}, {4}
  expect_equal(lsed:::comp_labels(4, 1L, 2L), c(1L, 1L, 2L, 3L))
})

test_that("comp_labels gives every isolated node its own label", {
  expect_equal(lsed:::comp_labels(3, integer(0), integer(0)), c(1L, 2L, 3L))
})

test_that("comp_labels is invariant to edge ordering", {
  a <- lsed:::comp_labels(5, c(1L, 3L, 4L), c(2L, 4L, 5L))
  b <- lsed:::comp_labels(5, c(4L, 1L, 3L), c(5L, 2L, 4L))
  expect_equal(a, b)
  # components {1,2} and {3,4,5}
  expect_equal(a, c(1L, 1L, 2L, 2L, 2L))
})

# ---------------------------------------------------------------------------
# snap_pieces
# ---------------------------------------------------------------------------

test_that("snap_pieces absorbs a sub-floor piece into its neighbour", {
  # 3 cells in a row (nc=3): pieces 1,1,2; piece 1 big, piece 2 small.
  piece <- c(1L, 1L, 2L)
  E <- lsed:::rook_edges(1:3, nc = 3, nr = 1)
  root <- lsed:::snap_pieces(
    piece,
    E$i,
    E$j,
    area = c(5, 1),
    band = c(1L, 1L),
    minac = 2
  )
  # piece 2 (area 1 < floor 2) snaps into piece 1; both resolve to one root
  expect_equal(length(unique(root)), 1L)
})

test_that("snap_pieces leaves above-floor pieces untouched", {
  piece <- c(1L, 1L, 2L)
  E <- lsed:::rook_edges(1:3, nc = 3, nr = 1)
  root <- lsed:::snap_pieces(
    piece,
    E$i,
    E$j,
    area = c(5, 5),
    band = c(1L, 1L),
    minac = 2
  )
  expect_equal(root, c(1L, 2L))
})

test_that("snap_pieces prefers the higher-band neighbour", {
  # cells row: piece2 | piece1(small) | piece3 ; piece1 touches both.
  piece <- c(2L, 1L, 3L)
  E <- lsed:::rook_edges(1:3, nc = 3, nr = 1)
  root <- lsed:::snap_pieces(
    piece,
    E$i,
    E$j,
    area = c(1, 3, 3), # per-piece: p1 small
    band = c(1L, 1L, 2L), # p3 is the higher band
    minac = c(2, 0)
  )
  # p1 merges into p3 (higher band), not p2
  expect_equal(root[1], 3L)
  expect_equal(root[3], 3L)
  expect_equal(root[2], 2L)
})

test_that("snap_pieces leaves a below-floor piece with no neighbour in place", {
  # cells 1 and 3 on a 3-wide row are not adjacent => no region-adjacency edge
  E <- lsed:::rook_edges(c(1L, 3L), nc = 3, nr = 1)
  root <- lsed:::snap_pieces(
    c(1L, 2L),
    E$i,
    E$j,
    area = c(1, 5),
    band = c(1L, 1L),
    minac = 2
  )
  expect_equal(root, c(1L, 2L)) # the isolated piece 1 has nowhere to go
})

test_that("snap_pieces idles once a piece's only neighbour is its own root", {
  # two adjacent pieces, both below the floor even after merging (1 + 1 < 5):
  # one absorbs the other, then the loop finds no distinct neighbour root to merge.
  E <- lsed:::rook_edges(1:2, nc = 2, nr = 1)
  root <- lsed:::snap_pieces(
    c(1L, 2L),
    E$i,
    E$j,
    area = c(1, 1),
    band = c(1L, 1L),
    minac = 5
  )
  expect_equal(length(unique(root)), 1L)
})

# ---------------------------------------------------------------------------
# kcap
# ---------------------------------------------------------------------------

test_that("kcap returns a single cluster when at or below the cap", {
  expect_equal(lsed:::kcap(1:5, capn = 5, nc = 10), rep(1L, 5))
  expect_equal(lsed:::kcap(1:3, capn = 10, nc = 10), rep(1L, 3))
})

test_that("kcap bounds every cluster at the cap and keeps all cells", {
  set.seed(1)
  gc <- cell_of(rep(0:9, each = 10), rep(0:9, times = 10), nc = 20) # 100 cells
  cl <- lsed:::kcap(gc, capn = 25, nc = 20)
  expect_length(cl, 100)
  expect_lte(max(tabulate(cl)), 25)
  expect_gte(length(unique(cl)), ceiling(100 / 25))
})

test_that("kcap bumps k past the equal-size target to honour the cap", {
  set.seed(1)
  # a dense 3x6 block plus two far outliers: the initial k = ceil(20/8) = 3 leaves an
  # over-cap cluster, so kcap increments k until every cluster fits.
  block <- as.integer(outer(0:2, 0:5, function(r, c) r * 100 + c + 1L))
  gc <- c(block, 5000L, 9000L)
  cl <- lsed:::kcap(gc, capn = 8, nc = 100)
  expect_lte(max(tabulate(cl)), 8)
  expect_gt(length(unique(cl)), ceiling(length(gc) / 8)) # k was bumped above the target
})

# ---------------------------------------------------------------------------
# papply / stitch_units (internal)
# ---------------------------------------------------------------------------

test_that("papply runs serially and preserves input order", {
  res <- lsed:::papply(list(1, 2, 3), function(x) x * 2, cores = 1)
  expect_equal(res, list(2, 4, 6))
})

test_that("papply surfaces a failing parallel worker as an error", {
  skip_on_os("windows") # mclapply forks only on unix; cores > 1 is serial on windows
  expect_error(
    suppressWarnings(
      # mclapply prints a worker-error warning we don't care about here
      lsed:::papply(list(1, 2), function(x) stop("boom"), cores = 2)
    ),
    "parallel subdivision failed"
  )
})

test_that("stitch_units offsets per-group labels into a global 1..N vector", {
  groups <- list(c(1L, 2L), c(3L, 4L))
  labs <- list(c(1L, 1L), c(1L, 2L))
  expect_equal(lsed:::stitch_units(groups, labs, 4), c(1L, 1L, 2L, 3L))
})

# ---------------------------------------------------------------------------
# unit_prob
# ---------------------------------------------------------------------------

test_that("unit_prob reduces to min/max/mean/n per group", {
  up <- lsed:::unit_prob(c(0.1, 0.3, 0.5, 0.9), grp = c(1L, 1L, 2L, 2L))
  expect_equal(up$id, c(1L, 2L))
  expect_equal(up$prob_min, c(0.1, 0.5))
  expect_equal(up$prob_max, c(0.3, 0.9))
  expect_equal(up$prob_mean, c(0.2, 0.7))
  expect_equal(up$n, c(2L, 2L))
})

# ---------------------------------------------------------------------------
# rollup_patches
# ---------------------------------------------------------------------------

test_that("rollup_patches aggregates units to parent patches exactly", {
  ap <- data.frame(
    unit = 1:3,
    patch = c(1L, 1L, 2L),
    n = c(2, 3, 4),
    prob_min = c(0.1, 0.2, 0.3),
    prob_max = c(0.5, 0.6, 0.7),
    prob_mean = c(0.3, 0.4, 0.5)
  )
  pp <- lsed:::rollup_patches(ap, cell_area = 4046.856) # acres == n
  expect_equal(pp$patch, c(1L, 2L))
  expect_equal(pp$prob_min, c(0.1, 0.3))
  expect_equal(pp$prob_max, c(0.6, 0.7))
  # patch 1 mean is n-weighted: (0.3*2 + 0.4*3) / 5
  expect_equal(pp$prob_mean, c((0.3 * 2 + 0.4 * 3) / 5, 0.5))
  expect_equal(pp$n, c(5, 4))
  expect_equal(pp$acres, c(5, 4), tolerance = 1e-6)
})

# ---------------------------------------------------------------------------
# band_subpatches / lsed:::cap_subpatches (full stage-2, pure vectors)
# ---------------------------------------------------------------------------

# A 10x10 solid patch of 100 cells, with a smooth probability ramp.
solid_patch <- function(nc = 10, nr = 10) {
  cells <- seq_len(nc * nr)
  col <- (cells - 1L) %% nc
  row <- (cells - 1L) %/% nc
  list(
    cells = cells,
    nc = nc,
    nr = nr,
    pval = 0.4 + 0.5 * (row + col) / (nc + nr - 2) # 0.4 .. 0.9 ramp
  )
}

test_that("band_subpatches passes a small patch through as a single unit", {
  g <- solid_patch(2, 2) # 4 cells
  u <- lsed:::band_subpatches(
    g$cells,
    memb = rep(1L, 4),
    pval = g$pval,
    nc = 2,
    nr = 2,
    cell_area = 4046.856, # 1 acre per cell
    band_brks = c(0.4, 0.55, 0.7, 0.85, 1.0001),
    band_minac = c(2, 1, 0.5, 0),
    trig_ac = 20,
    cap_cells = 100
  )
  expect_equal(u, rep(1L, 4)) # below trig_ac => untouched
})

test_that("band_subpatches numbers units sequentially across patches", {
  # two small (below-trigger) patches => one unit each, numbered 1 then 2
  u <- lsed:::band_subpatches(
    cells = 1:4,
    memb = c(1L, 1L, 2L, 2L),
    pval = rep(0.6, 4),
    nc = 4,
    nr = 1,
    cell_area = 4046.856,
    band_brks = c(0.4, 0.55, 0.7, 0.85, 1.0001),
    band_minac = c(2, 1, 0.5, 0),
    trig_ac = 20,
    cap_cells = 100
  )
  expect_equal(u, c(1L, 1L, 2L, 2L))
})

test_that("band_subpatches caps units, labels every cell, and is deterministic", {
  g <- solid_patch()
  args <- list(
    g$cells,
    memb = rep(1L, 100),
    pval = g$pval,
    nc = g$nc,
    nr = g$nr,
    cell_area = 4046.856,
    band_brks = c(0.4, 0.55, 0.7, 0.85, 1.0001),
    band_minac = c(2, 1, 0.5, 0),
    trig_ac = 20,
    cap_cells = 30
  )
  u1 <- do.call(lsed:::band_subpatches, args)
  u2 <- do.call(lsed:::band_subpatches, args)
  expect_length(u1, 100)
  expect_true(all(u1 >= 1L))
  expect_setequal(unique(u1), seq_len(max(u1))) # labels are 1..K with no gaps
  expect_lte(max(tabulate(u1)), 30) # geometric cap respected
  expect_equal(u1, u2) # deterministic
})

test_that("band_subpatches is invariant to worker count", {
  skip_on_os("windows")
  g <- solid_patch()
  common <- list(
    g$cells,
    pval = g$pval,
    nc = g$nc,
    nr = g$nr,
    cell_area = 4046.856,
    band_brks = c(0.4, 0.55, 0.7, 0.85, 1.0001),
    band_minac = c(2, 1, 0.5, 0),
    trig_ac = 5,
    cap_cells = 30
  )
  # two patches so there is something to parallelise over
  memb <- c(rep(1L, 50), rep(2L, 50))
  serial <- do.call(
    lsed:::band_subpatches,
    c(common, list(memb = memb, cores = 1))
  )
  par <- do.call(
    lsed:::band_subpatches,
    c(common, list(memb = memb, cores = 2))
  )
  expect_equal(serial, par)
})

test_that("cap_subpatches caps units and is deterministic", {
  # 1 acre per cell, 30-acre cap => cap_cells = 30; 100 cells split into >= 4 units.
  u1 <- lsed:::cap_subpatches(
    1:100,
    memb = rep(1L, 100),
    nc = 10,
    cell_area = 4046.856,
    max_area_ac = 30
  )
  u2 <- lsed:::cap_subpatches(
    1:100,
    memb = rep(1L, 100),
    nc = 10,
    cell_area = 4046.856,
    max_area_ac = 30
  )
  expect_length(u1, 100)
  expect_setequal(unique(u1), seq_len(max(u1)))
  expect_lte(max(tabulate(u1)), 30L)
  expect_gte(length(unique(u1)), ceiling(100 / 30))
  expect_equal(u1, u2)
})

test_that("cap_subpatches passes an under-cap patch through as one unit", {
  u <- lsed:::cap_subpatches(
    1:4,
    memb = rep(1L, 4),
    nc = 2,
    cell_area = 4046.856,
    max_area_ac = 10
  )
  expect_equal(u, rep(1L, 4))
})

# ---------------------------------------------------------------------------
# terra-dependent helpers
# ---------------------------------------------------------------------------

test_that("drop_slivers removes patches at/below min_area and keeps the rest", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 3, xmin = 0, xmax = 3, ymin = 0, ymax = 2)
  terra::values(r) <- c(1, 1, 1, 2, NA, NA) # patch 1: 3 cells; patch 2: 1 cell
  out <- lsed:::drop_slivers(r, min_area = 1.5) # cell area = 1 => patch 2 (area 1) dropped
  v <- terra::values(out)[, 1]
  expect_equal(sum(v == 1, na.rm = TRUE), 3L)
  expect_equal(sum(v == 2, na.rm = TRUE), 0L) # patch 2 gone
  expect_true(is.na(v[4])) # its cell is now NA
})

test_that("drop_slivers is a no-op when no patch falls below min_area", {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  terra::values(r) <- c(1, 1, 2, 2) # both patches 2 cells; cell area 1
  out <- lsed:::drop_slivers(r, min_area = 0) # nothing at/below 0 => raster returned unchanged
  expect_equal(terra::values(out)[, 1], c(1, 1, 2, 2))
})

test_that("labels_to_raster scatters values to cells and NA elsewhere", {
  skip_if_not_installed("terra")
  tmpl <- terra::rast(
    nrows = 2,
    ncols = 2,
    xmin = 0,
    xmax = 2,
    ymin = 0,
    ymax = 2
  )
  r <- lsed:::labels_to_raster(
    tmpl,
    cells = c(1L, 4L),
    vals = c(7L, 9L),
    name = "unit"
  )
  v <- terra::values(r)[, 1]
  expect_equal(v, c(7L, NA, NA, 9L))
  expect_equal(names(r), "unit")
})

test_that("aoa_fraction reports the in-domain cell fraction per region", {
  skip_if_not_installed("terra")
  id <- terra::rast(
    nrows = 1,
    ncols = 4,
    xmin = 0,
    xmax = 4,
    ymin = 0,
    ymax = 1
  )
  terra::values(id) <- c(1, 1, 2, 2)
  di <- terra::rast(id)
  terra::values(di) <- c(0.5, 2, 0.1, 0.2) # region 1: 1 of 2 in; region 2: 2 of 2 in
  fr <- lsed:::aoa_fraction(di, id, aoa_thresh = 1)
  expect_named(fr, c("id", "frac_in_aoa"))
  expect_equal(fr$frac_in_aoa[fr$id == 1], 0.5)
  expect_equal(fr$frac_in_aoa[fr$id == 2], 1)
})

test_that("crop_to_cells shrinks to localised data but leaves spread data alone", {
  skip_if_not_installed("terra")
  r <- terra::rast(
    nrows = 10,
    ncols = 10,
    xmin = 0,
    xmax = 10,
    ymin = 0,
    ymax = 10
  )
  terra::values(r) <- seq_len(100)
  # localised: top-left 2x2 block -> should crop smaller
  local_cells <- c(
    cell_of(0, 0, 10),
    cell_of(0, 1, 10),
    cell_of(1, 0, 10),
    cell_of(1, 1, 10)
  )
  cr <- lsed:::crop_to_cells(r, local_cells, frac = 0.5)
  expect_lt(terra::ncell(cr), terra::ncell(r))
  # spread across the whole extent -> unchanged
  full <- lsed:::crop_to_cells(r, c(1L, 100L), frac = 0.5)
  expect_equal(as.vector(terra::ext(full)), as.vector(terra::ext(r)))
})

test_that("polygonize_units dissolves ids and joins attributes", {
  skip_if_not_installed("terra")
  id <- terra::rast(
    nrows = 1,
    ncols = 2,
    xmin = 0,
    xmax = 2,
    ymin = 0,
    ymax = 1
  )
  terra::values(id) <- c(1, 2)
  names(id) <- "unit"
  attrs <- data.frame(unit = c(1L, 2L), acres = c(3.5, 7.0))
  p <- lsed:::polygonize_units(id, attrs)
  expect_s4_class(p, "SpatVector")
  expect_true("acres" %in% names(p))
  expect_equal(sort(terra::values(p)$acres), c(3.5, 7.0))
})

test_that("cache_rast computes then reuses a cached raster by signature", {
  skip_if_not_installed("terra")
  dir <- withr::local_tempdir()
  tif <- file.path(dir, "r.tif")
  sigp <- file.path(dir, "r.sig")
  calls <- 0L
  make <- function() {
    calls <<- calls + 1L # nolint: undesirable_operator_linter. lexical-scope counter
    r <- terra::rast(
      nrows = 2,
      ncols = 2,
      xmin = 0,
      xmax = 2,
      ymin = 0,
      ymax = 2
    )
    terra::values(r) <- 1:4
    r
  }
  a <- lsed:::cache_rast(tif, sigp, "sig-A", make)
  b <- lsed:::cache_rast(tif, sigp, "sig-A", make) # same sig => cached, no recompute
  expect_equal(calls, 1L)
  expect_equal(terra::values(a)[, 1], terra::values(b)[, 1])
  # a changed signature forces a recompute
  lsed:::cache_rast(tif, sigp, "sig-B", make)
  expect_equal(calls, 2L)
})

# ---------------------------------------------------------------------------
# lsed:::merge_offmask (post-watershed assembly; no WhiteboxTools needed)
# ---------------------------------------------------------------------------

test_that("merge_offmask keeps watershed labels and ids off-mask cells above them", {
  skip_if_not_installed("terra")
  # 2x4 grid: two watershed basins (ids 1, 2), two suitable cells the watershed left
  # as background (5, 6), and two unsuitable cells (7, 8).
  seg <- terra::rast(
    nrows = 2,
    ncols = 4,
    xmin = 0,
    xmax = 4,
    ymin = 0,
    ymax = 2
  )
  terra::values(seg) <- c(1, 1, 2, 2, 0, 0, 0, 0)
  mask <- terra::setValues(
    seg,
    c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE)
  )
  out <- lsed:::merge_offmask(seg, mask)
  # off-mask leftovers (cells 5-6) become a new id shifted above the max basin id (2)
  expect_equal(terra::values(out)[, 1], c(1, 1, 2, 2, 3, 3, NA, NA))
})

test_that("merge_offmask returns pure watershed labels when none drained off-mask", {
  skip_if_not_installed("terra")
  seg <- terra::rast(
    nrows = 1,
    ncols = 4,
    xmin = 0,
    xmax = 4,
    ymin = 0,
    ymax = 1
  )
  terra::values(seg) <- c(1, 1, 2, 2)
  mask <- terra::setValues(seg, rep(TRUE, 4))
  out <- lsed:::merge_offmask(seg, mask)
  expect_equal(terra::values(out)[, 1], c(1, 1, 2, 2)) # nothing to add
})

# ---------------------------------------------------------------------------
# survey_units orchestration, with the patch stage pre-seeded in the cache so
# the WhiteboxTools watershed is bypassed (deterministic, no external binary).
# ---------------------------------------------------------------------------

# Build an in-memory probability surface and seed cache_dir with a hand-made patch
# raster whose signature matches what survey_units computes, so delineate_patches
# (and WhiteboxTools) are never called.
seed_patch_cache <- function(
  n = 24,
  sens_spec = 0.45,
  delta = 0.05,
  min_area = 10
) {
  skip_if_not_installed("terra")
  pr <- terra::rast(
    nrows = n,
    ncols = n,
    xmin = 0,
    xmax = n,
    ymin = 0,
    ymax = n
  )
  rc <- terra::rowColFromCell(pr, seq_len(terra::ncell(pr)))
  terra::values(pr) <- 0.46 + 0.5 * (rc[, 1] + rc[, 2]) / (2 * (n - 1)) # 0.46 .. ~0.96
  names(pr) <- "prob"
  stopifnot(!nzchar(terra::sources(pr))) # must stay in memory for a stable signature

  # two patches: top half vs bottom half, every cell assigned (no NA)
  patch <- terra::rast(pr)
  terra::values(patch) <- ifelse(rc[, 1] <= n / 2, 1L, 2L)

  cache <- withr::local_tempdir(.local_envir = parent.frame())
  base_sig <- paste(sens_spec, delta, min_area, sep = "|")
  terra::writeRaster(patch, file.path(cache, "patches.tif"))
  writeLines(base_sig, file.path(cache, "patches.sig"))
  list(
    pr = pr,
    cache = cache,
    sens_spec = sens_spec,
    delta = delta,
    min_area = min_area
  )
}

test_that("survey_units (kmeans) runs from a seeded cache, tags AOA, caches polygons", {
  s <- seed_patch_cache()
  occ <- terra::vect(
    rbind(c(6, 6), c(18, 18)),
    type = "points",
    crs = terra::crs(s$pr)
  )
  di <- terra::setValues(s$pr, 3 * (1 - terra::values(s$pr)[, 1])) # some in, some out
  wd <- withr::local_tempdir()
  gpkg <- file.path(withr::local_tempdir(), "units.gpkg")
  run <- function() {
    survey_units(
      s$pr,
      occ,
      method = "kmeans",
      sens_spec = s$sens_spec,
      delta = s$delta,
      min_area = s$min_area,
      max_area_ac = 0.05, # ~202-cell cap => each 288-cell patch splits
      aoa_di = di,
      aoa_thresh = 1,
      work_dir = wd,
      cache_dir = s$cache,
      out_gpkg = gpkg,
      seed = 1
    )
  }
  res <- run()
  expect_equal(res$summary$n_patches, 2)
  expect_gt(res$summary$n_units, res$summary$n_patches) # the cap forced splits
  expect_equal(res$summary$n_units, max(res$units$unit))
  expect_lte(max(res$units$acres), 0.05 + 1e-6)
  expect_true(all(c("frac_in_aoa", "in_aoa") %in% names(res$units)))
  expect_false(is.na(res$summary$n_in_aoa))
  expect_gt(res$summary$n_units_occ, 0) # the two points sit on units
  expect_equal(length(res$polygons), nrow(res$units))
  expect_true(file.exists(gpkg))
  # second call reuses the unit + polygon caches and matches
  res2 <- run()
  expect_equal(res2$units$unit, res$units$unit)
  expect_s4_class(res2$polygons, "SpatVector")
})

test_that("survey_units (band) runs from a seeded cache and fills band attributes", {
  s <- seed_patch_cache()
  occ <- terra::vect(
    rbind(c(6, 6), c(18, 18)),
    type = "points",
    crs = terra::crs(s$pr)
  )
  wd <- withr::local_tempdir()
  res <- survey_units(
    s$pr,
    occ,
    method = "band",
    sens_spec = s$sens_spec,
    delta = s$delta,
    min_area = s$min_area,
    band_brks = c(0.45, 0.6, 0.75, 0.9, 1.0001),
    band_minac = c(0.05, 0.03, 0.01, 0),
    trig_ac = 0.05,
    maxcap_ac = 0.05,
    work_dir = wd,
    cache_dir = s$cache,
    seed = 1
  )
  expect_true("band" %in% names(res$units))
  expect_true(all(res$units$band >= 1L & res$units$band <= 4L))
  expect_false(is.na(res$summary$n_high)) # band-only summary column populated
  expect_equal(res$summary$n_units, max(res$units$unit))
  expect_setequal(res$patches$patch, sort(unique(res$units$patch)))
})

test_that("survey_units takes file-path inputs and a source-aware cache signature", {
  skip_if_not_installed("terra")
  n <- 24
  sens <- 0.45
  delta <- 0.05
  minar <- 10
  pr <- terra::rast(
    nrows = n,
    ncols = n,
    xmin = 0,
    xmax = n,
    ymin = 0,
    ymax = n
  )
  rc <- terra::rowColFromCell(pr, seq_len(terra::ncell(pr)))
  terra::values(pr) <- 0.46 + 0.5 * (rc[, 1] + rc[, 2]) / (2 * (n - 1))
  names(pr) <- "prob"
  patch <- terra::setValues(terra::rast(pr), ifelse(rc[, 1] <= n / 2, 1L, 2L))
  di <- terra::setValues(pr, 3 * (1 - terra::values(pr)[, 1]))
  occ <- terra::vect(
    rbind(c(6, 6), c(18, 18)),
    type = "points",
    crs = terra::crs(pr)
  )

  io <- withr::local_tempdir()
  pr_path <- file.path(io, "pr.tif")
  occ_path <- file.path(io, "occ.gpkg")
  di_path <- file.path(io, "di.tif")
  terra::writeRaster(pr, pr_path)
  terra::writeVector(occ, occ_path)
  terra::writeRaster(di, di_path)

  # seed the cache with the signature survey_units builds for an on-disk source:
  # the threshold triple PLUS the source basename and size.
  cache <- withr::local_tempdir()
  src <- terra::sources(terra::rast(pr_path))[1]
  base_sig <- paste(
    paste(sens, delta, minar, sep = "|"),
    basename(src),
    file.info(src)$size,
    sep = "|"
  )
  terra::writeRaster(patch, file.path(cache, "patches.tif"))
  writeLines(base_sig, file.path(cache, "patches.sig"))

  wd <- withr::local_tempdir()
  res <- survey_units(
    pr_path,
    occ_path, # character paths exercise the rast()/vect() coercion
    method = "kmeans",
    sens_spec = sens,
    delta = delta,
    min_area = minar,
    max_area_ac = 0.05,
    aoa_di = di_path, # character path exercises the aoa rast() coercion
    aoa_thresh = 1,
    work_dir = wd,
    cache_dir = cache,
    seed = 1
  )
  expect_equal(res$summary$n_patches, 2) # cache hit => no watershed was run
  expect_true(all(c("frac_in_aoa", "in_aoa") %in% names(res$units)))
  expect_false(is.na(res$summary$n_in_aoa))
})

# ---------------------------------------------------------------------------
# WhiteboxTools-dependent pipeline (lsed:::delineate_patches, survey_units end to end).
# Opt-in only (LSED_TEST_WBT=true): the external binary is flaky under repeated
# invocation, so these are excluded from the default run.
# ---------------------------------------------------------------------------

# A suitability surface for the real WhiteboxTools pipeline. The watershed needs a
# DEM that drains to an outlet; a suitable patch marooned in NA has none (the fill
# flattens it, so no interior sink survives). Setting the base >= sens_spec makes the
# whole grid suitable, so the mask reaches the raster edge (a real outlet) and the two
# Gaussian peaks become two drainable pits -> two basins.
two_basin_surface <- function(n = 64) {
  skip_if_not_installed("terra")
  r <- terra::rast(nrows = n, ncols = n, xmin = 0, xmax = n, ymin = 0, ymax = n)
  xy <- terra::xyFromCell(r, seq_len(terra::ncell(r)))
  base <- 0.5
  peak <- function(cx, cy) {
    base + (1 - base) * exp(-((xy[, 1] - cx)^2 + (xy[, 2] - cy)^2) / (2 * 8^2))
  }
  terra::values(r) <- pmax(peak(18, 18), peak(46, 46))
  names(r) <- "prob"
  r
}

test_that("delineate_patches segments a drainable surface into aligned patches", {
  skip_if_no_wbt()
  pr <- two_basin_surface()
  wd <- withr::local_tempdir()
  pid <- lsed:::delineate_patches(
    pr,
    sens_spec = 0.45,
    delta = 0.05,
    min_area = 50,
    rdir = wd
  )
  expect_s4_class(pid, "SpatRaster")
  expect_equal(as.vector(terra::ext(pid)), as.vector(terra::ext(pr)))
  expect_equal(terra::res(pid), terra::res(pr))
  ids <- terra::unique(pid)[, 1]
  ids <- ids[!is.na(ids)]
  expect_gte(length(ids), 2) # the two peaks are distinct basins
  # a labelled cell is always a suitable cell
  suit <- terra::values(pr)[, 1] >= 0.45
  labelled <- !is.na(terra::values(pid)[, 1])
  expect_true(all(!labelled | suit))
})

test_that("survey_units (kmeans) runs the whole pipeline and returns a coherent bundle", {
  skip_if_no_wbt()
  pr <- two_basin_surface()
  occ <- terra::vect(
    rbind(c(18, 18), c(46, 46)),
    type = "points",
    crs = terra::crs(pr)
  )
  wd <- withr::local_tempdir()
  res <- survey_units(
    pr,
    occ,
    method = "kmeans",
    sens_spec = 0.45,
    delta = 0.05,
    min_area = 50,
    max_area_ac = 0.1, # ~404-cell cap => each basin splits into several units
    work_dir = wd,
    seed = 1
  )
  expect_named(
    res,
    c("patch_raster", "unit_raster", "patches", "units", "polygons", "summary")
  )
  expect_s4_class(res$unit_raster, "SpatRaster")
  expect_s4_class(res$polygons, "SpatVector")
  expect_gte(res$summary$n_patches, 2)
  expect_gt(res$summary$n_units, res$summary$n_patches) # the cap forced splits
  expect_equal(res$summary$n_units, max(res$units$unit))
  # occupancy: the two presences sit on patches, so some units are occupied
  expect_gt(res$summary$n_units_occ, 0)
  # unit acreage never exceeds the cap
  expect_lte(max(res$units$acres), 0.1 + 1e-6)
  # patch table rolls up to exactly the patch ids present in the unit table
  expect_setequal(res$patches$patch, sort(unique(res$units$patch)))
  # one dissolved polygon per unit
  expect_equal(length(res$polygons), nrow(res$units))
})

test_that("survey_units (band) populates band attributes and caches on re-run", {
  skip_if_no_wbt()
  pr <- two_basin_surface()
  occ <- terra::vect(
    rbind(c(18, 18), c(46, 46)),
    type = "points",
    crs = terra::crs(pr)
  )
  wd <- withr::local_tempdir()
  cache <- withr::local_tempdir()
  args <- list(
    pr,
    occ,
    method = "band",
    sens_spec = 0.45,
    delta = 0.05,
    min_area = 50,
    band_brks = c(0.45, 0.6, 0.75, 0.9, 1.0001),
    band_minac = c(0.05, 0.03, 0.01, 0),
    trig_ac = 0.05,
    maxcap_ac = 0.1,
    work_dir = wd,
    cache_dir = cache,
    seed = 1
  )
  res <- do.call(survey_units, args)
  expect_true("band" %in% names(res$units))
  expect_true(all(res$units$band >= 1L & res$units$band <= 4L))
  expect_false(is.na(res$summary$n_high)) # band-only summary column is populated
  expect_gte(res$summary$n_units, res$summary$n_patches)
  # a second identical call reuses the cached rasters and returns the same units
  res2 <- do.call(survey_units, args)
  expect_equal(res2$units$unit, res$units$unit)
  expect_equal(
    terra::values(res2$unit_raster)[, 1],
    terra::values(res$unit_raster)[, 1]
  )
})

test_that("survey_units accepts file-path inputs, tags AOA, and caches polygons", {
  skip_if_no_wbt()
  pr <- two_basin_surface()
  # a dissimilarity surface: in-domain (DI <= 1) only on the higher-suitability core,
  # so some units are tagged in-AOA and some out.
  di <- terra::setValues(pr, 3 * (1 - terra::values(pr)[, 1]))
  occ <- terra::vect(
    rbind(c(18, 18), c(46, 46)),
    type = "points",
    crs = terra::crs(pr)
  )

  wd <- withr::local_tempdir()
  io <- withr::local_tempdir()
  pr_path <- file.path(io, "pr.tif")
  occ_path <- file.path(io, "occ.gpkg")
  di_path <- file.path(io, "di.tif")
  gpkg <- file.path(io, "units.gpkg")
  terra::writeRaster(pr, pr_path)
  terra::writeVector(occ, occ_path)
  terra::writeRaster(di, di_path)

  call_it <- function() {
    survey_units(
      pr_path,
      occ_path, # character paths exercise the rast()/vect() coercion
      method = "kmeans",
      sens_spec = 0.45,
      delta = 0.05,
      min_area = 50,
      max_area_ac = 0.1,
      aoa_di = di_path, # path exercises the rast() coercion inside survey_units
      aoa_thresh = 1,
      work_dir = wd,
      out_gpkg = gpkg,
      seed = 1
    )
  }

  res <- call_it() # first call: computes and writes the gpkg
  expect_true(all(c("frac_in_aoa", "in_aoa") %in% names(res$units)))
  expect_true(all(res$units$frac_in_aoa >= 0 & res$units$frac_in_aoa <= 1))
  expect_type(res$units$in_aoa, "logical")
  expect_false(is.na(res$summary$n_in_aoa))
  expect_true(file.exists(gpkg))

  res2 <- call_it() # second call: reads the cached gpkg back
  expect_s4_class(res2$polygons, "SpatVector")
  expect_equal(length(res2$polygons), length(res$polygons))
})

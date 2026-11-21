# Delineate survey units end to end

One call runs the whole pipeline: **watershed -\> patches -\> subdivide
-\> attributes -\> polygons**. It binarises and delineates patches
([`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md)),
subdivides each oversized patch by the chosen lever (`method = "band"`
-\>
[`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md);
`method = "kmeans"` -\>
[`cap_subpatches`](https://sagesteppe.github.io/lsed/reference/cap_subpatches.md)),
scores per-unit and per-patch probability
([`unit_prob`](https://sagesteppe.github.io/lsed/reference/unit_prob.md)),
occupancy (a single point overlay), acreage, priority band, and optional
AOA tag, and returns both the patch- and unit-level results plus a
one-row summary. Only the **suitable** cells are ever read into memory
(via
[`terra::cells`](https://rspatial.github.io/terra/reference/cells.html) +
indexed reads), so peak memory scales with the suitable set, not the
landscape.

## Usage

``` r
survey_units(
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
)
```

## Arguments

- pr:

  Probability surface: a `SpatRaster` or a path to one.

- occ_pts:

  Occurrence points: a `SpatVector` or a path to one (same CRS as `pr`).

- method:

  Subdivision lever: `"band"` (suitability banding) or `"kmeans"`
  (geometric cap).

- sens_spec, delta, min_area:

  Patch delineation thresholds (see
  [`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md)).

- band_brks, band_minac, trig_ac, maxcap_ac:

  Banding-lever parameters (see
  [`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md)).

- max_area_ac:

  k-means-lever cap in acres (see
  [`cap_subpatches`](https://sagesteppe.github.io/lsed/reference/cap_subpatches.md)).

- aoa_di:

  Optional DI surface (`SpatRaster` or path) for the AOA tag; `NULL` to
  skip.

- aoa_thresh:

  In-domain DI threshold.

- work_dir:

  Directory for the watershed intermediate rasters (defaults to a temp
  dir).

- cache_dir:

  Optional directory to memoise the patch/unit rasters; `NULL` disables.

- out_gpkg:

  Optional path to write (and cache) the unit polygons.

- seed:

  Base random seed for the k-means steps (applied per patch; see
  [`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md)).

- cores:

  Integer worker count for the per-patch subdivision (`1` = serial).
  Output is identical for any core count, so `cores` only affects speed,
  not the result or the cache. Forks via parallel; serial on Windows.

## Value

A list: `patch_raster`, `unit_raster` (`SpatRaster`s); `patches`,
`units` (per-patch and per-unit attribute tables); `polygons` (unit
`SpatVector`); and `summary` (one-row data.frame).

## Details

Heavy steps are memoised when `cache_dir` is set: the patch raster, the
unit raster, and (when `out_gpkg` is given) the polygons are reused
unless a signature of the inputs changes.

## See also

[`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md),
[`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md),
[`cap_subpatches`](https://sagesteppe.github.io/lsed/reference/cap_subpatches.md)

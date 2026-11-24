# Build the survey-intensity surface in one call

The package's front door for the `S` term: weights the records
([`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)),
assembles the continuous field
([`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md))
and renders it to a raster view
([`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md)).
The field is built once and never pre-binned; the raster is only a view
at the resolution of `template`/`res`.

## Usage

``` r
survey_surface(
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
)
```

## Arguments

- coords:

  two-column matrix/data.frame of record coordinates (metres, in the
  domain's planar CRS).

- species:

  vector of species labels, one per record.

- template:

  a terra `SpatRaster` (geometry/CRS matched) or a `SpatExtent`; with an
  extent, give `res`.

- res:

  cell size in map units when `template` is an extent.

- sigma:

  kernel bandwidth \\\sigma\\ in metres (default `100`).

- domain:

  study-domain polygon for the p95-box correction (sf / `SpatVector` /
  `SpatExtent`); defaults to `template`'s extent when `NULL` and a
  raster/extent is given.

- min_records, p, damp, trunc:

  passed to
  [`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)
  /
  [`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md).

- record_type, plot_types, plot_weight:

  plot-vs-opportunistic handling, passed to
  [`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md).
  If `record_type` is `NULL` but `origin` is given, it is derived with
  [`guess_record_type`](https://sagesteppe.github.io/lsed/reference/guess_record_type.md).

- basis, basis_weights:

  per-record `basisOfRecord` and its weight multipliers, passed to
  [`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md)
  (default up-weights herbarium specimens 1.5x over observations).

- origin:

  optional dataset/origin labels (one per record); used only to infer
  `record_type` when that is not supplied.

- rescale, q:

  bring the view onto \\\[0, 1\]\\ (defaults `"quantile"`, `0.95`); see
  [`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md).

- invert:

  if `TRUE`, return survey *sparsity* \\1 - \tilde S\\ - the form the
  `RankIndex` consumes (well-surveyed ground scores low). Default
  `FALSE` returns the intensity surface \\S\\ itself.

- weights:

  optional precomputed per-species weights (skips
  [`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md));
  see
  [`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md).

- filename:

  optional output path; `...` passes to
  [`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html).

- ...:

  further arguments passed to
  [`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html)
  (via
  [`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md)),
  e.g. `overwrite` or `gdal`.

## Value

a single-layer `SpatRaster` of \\S\\ (or \\1 - \tilde S\\ when
`invert = TRUE`).

## See also

[`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)
for the per-species weights/floor,
[`guess_record_type`](https://sagesteppe.github.io/lsed/reference/guess_record_type.md)
for flagging plot datasets.

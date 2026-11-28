# Residual-kriging bias correction of a prediction raster, end to end

The single entry point for the correction pipeline. Given points
carrying signed residuals (from `point_residuals`), it fits a variogram,
krige the residuals onto `newdata` (optionally as a bootstrap ensemble
for uncertainty), and adds the resulting correction surface back onto
`pred`. When the residuals show no spatial structure (a pure-nugget
variogram) there is nothing to interpolate: the function warns and
returns `pred` unchanged.

## Usage

``` r
reduce_spatial_bias(
  points,
  newdata,
  pred = newdata,
  resid = "resid",
  aoa = NULL,
  aoa_thresh = 1,
  bootstrap = FALSE,
  n = 199,
  cores = NULL,
  vgm_model = "Exp",
  nugget_cut = 0.9,
  clamp = c(0, 1),
  outside = c("keep", "na"),
  seed = NULL,
  ...
)
```

## Arguments

- points:

  An `sf` point layer carrying a residual column (see
  [`point_residuals`](https://sagesteppe.github.io/lsed/reference/point_residuals.md)).

- newdata:

  Where to krige the correction: an `sf` point layer or, more usually, a
  coarse `terra` `SpatRaster` template. Kriging every cell of a fine
  grid is expensive, so keep this coarser than `pred`.

- pred:

  A `SpatRaster` of predicted suitability to correct. Defaults to
  `newdata` when that is itself a raster.

- resid:

  Name of the residual column (default `"resid"`).

- aoa:

  Area-of-applicability restricting where the correction is produced: a
  `SpatRaster` dissimilarity-index (DI) surface (in-AOA where
  `di <= aoa_thresh`, the package convention) or an `sf`/`SpatVector`
  polygon. `NULL` predicts everywhere in `newdata`.

- aoa_thresh:

  In-domain DI threshold for a raster `aoa` (default 1).

- bootstrap:

  Whether to build the correction as a point-resampling ensemble (`n`
  draws) rather than a single kriging. The ensemble mean is used as the
  correction and its standard deviation is returned for uncertainty.

- n:

  Number of bootstrap resamples when `bootstrap = TRUE`.

- cores:

  Worker processes for the bootstrap (see `bootstrap_correction`);
  ignored unless `bootstrap = TRUE`.

- vgm_model:

  Variogram model form to fit, e.g. `"Exp"`, `"Sph"`.

- nugget_cut:

  Nugget-to-sill ratio at or above which the field is treated as pure
  nugget (no spatial structure) and left uncorrected.

- clamp:

  Range to clamp the corrected values to (default `c(0, 1)`; `NULL` to
  skip).

- outside:

  What to do where the correction is `NA` (outside the AOA): `"keep"`
  the original prediction (default) or `"na"` to blank it.

- seed:

  Optional RNG seed for the bootstrap.

- ...:

  Passed to
  [`krige`](https://r-spatial.github.io/gstat/reference/krige.html)
  (e.g. `nmax`).

## Value

A list with `corrected` (the corrected `SpatRaster`), `correction` (the
kriged correction surface, or `NULL` when pure nugget) and `variogram`
(the fitted-variogram diagnostics).

## See also

[`point_residuals`](https://sagesteppe.github.io/lsed/reference/point_residuals.md)

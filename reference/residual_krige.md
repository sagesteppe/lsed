# Ordinary kriging of residuals onto new locations (the correction surface)

Ordinary kriging of residuals onto new locations (the correction
surface)

## Usage

``` r
residual_krige(
  points,
  newdata,
  resid = "resid",
  model,
  aoa = NULL,
  aoa_thresh = 1,
  ...
)
```

## Arguments

- points:

  An `sf` point layer carrying a residual column.

- newdata:

  Where to predict: an `sf` point layer, or a `terra` `SpatRaster`
  template (non-`NA` cell centres are used and a raster is returned).
  Keep raster templates coarse - kriging every cell of a fine grid is
  expensive.

- resid:

  Name of the residual column (default `"resid"`).

- model:

  A fitted variogram model (e.g. `residual_variogram()$model`).

- aoa:

  Area-of-applicability restricting where the correction is produced: a
  `SpatRaster` dissimilarity-index surface (in-AOA where
  `di <= aoa_thresh`) or an `sf`/`SpatVector` polygon (see
  `restrict_to_aoa`). `NULL` predicts everywhere in `newdata`.

- aoa_thresh:

  In-domain DI threshold for a raster `aoa` (default 1).

- ...:

  Passed to
  [`krige`](https://r-spatial.github.io/gstat/reference/krige.html)
  (e.g. `nmax`).

## Value

`newdata` with the kriged correction (`var1.pred`) and variance
(`var1.var`); a `SpatRaster` of both when `newdata` is a raster.
Locations outside `aoa` are dropped (points) or `NA` (raster).

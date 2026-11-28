# Spatial residual diagnostics and residual-kriging correction for SDM predictions

A small pipeline for the question a pooled decision curve cannot answer:
are a model's errors spatially structured, and if so can that structure
be turned into a bias-correction surface? Call
[`point_residuals()`](https://sagesteppe.github.io/lsed/reference/point_residuals.md)
to attach the signed difference \\y - \hat p\\ between observed
occurrence and predicted suitability, then
[`reduce_spatial_bias()`](https://sagesteppe.github.io/lsed/reference/reduce_spatial_bias.md)
to run the rest end to end: fit a variogram to the residuals, krige them
(optionally with a bootstrap ensemble) onto a prediction grid, and add
that correction back onto the prediction raster. Depends on sf, gstat,
terra.

## Usage

``` r
restrict_to_aoa(newdata, aoa, aoa_thresh = 1, crs = sf::st_crs(newdata))
```

## Arguments

- newdata:

  An `sf` point layer or a `terra` `SpatRaster`.

- aoa:

  The AOA as a `SpatRaster` dissimilarity-index surface (in-AOA where
  `di <= aoa_thresh`) or an `sf`/`SpatVector` polygon. `NULL` returns
  `newdata` unchanged.

- aoa_thresh:

  In-domain DI threshold for a raster `aoa` (default 1).

- crs:

  CRS to align a polygon `aoa` against (the points' CRS).

## Value

`newdata` masked (raster) or filtered (points) to the AOA.

## Details

The individual stages -
[`residual_variogram()`](https://sagesteppe.github.io/lsed/reference/residual_variogram.md),
[`residual_krige()`](https://sagesteppe.github.io/lsed/reference/residual_krige.md),
[`bootstrap_correction()`](https://sagesteppe.github.io/lsed/reference/bootstrap_correction.md)
and
[`apply_residual_correction()`](https://sagesteppe.github.io/lsed/reference/apply_residual_correction.md) -
are internal and driven by
[`reduce_spatial_bias()`](https://sagesteppe.github.io/lsed/reference/reduce_spatial_bias.md).

Sign convention throughout: a POSITIVE residual is a site the model
UNDER-rates (observed exceeds predicted); a negative residual is one it
over-rates.

The correction surface is only trustworthy where the model interpolates,
so the kriging stages take an `aoa` (a dissimilarity-index surface,
in-AOA where `di <= aoa_thresh`, or a polygon) and predict inside it
only; outside the AOA no correction is produced. Restrict prediction
locations to the area of applicability

The AOA follows the package convention (see `aoa_fraction`): a raster
`aoa` is a CAST dissimilarity-index (DI) surface, in-AOA where
`di <= aoa_thresh`. A polygon `aoa` is taken as the in-AOA region
directly.

# Signed residuals between observed occurrence and predicted suitability

The residual is the difference \\y - \hat p\\ on the suitability
(probability) scale, so it can be kriged and added straight back onto a
prediction (see `apply_residual_correction`). A POSITIVE residual is a
site the model UNDER-rates (observed exceeds predicted).

## Usage

``` r
point_residuals(points, observed, predicted, layer = 1)
```

## Arguments

- points:

  An `sf` point layer.

- observed:

  Column name in `points`, or a numeric 0/1 vector, of the observed
  occurrence.

- predicted:

  The predicted suitability: a `terra` `SpatRaster` (sampled at the
  points), a column name in `points`, or a numeric vector.

- layer:

  For a raster `predicted`, the layer to sample (name or index; default
  the first).

## Value

`points` with added columns `pred` and `resid`.

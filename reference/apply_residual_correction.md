# Apply a residual correction to a prediction raster

Adds a correction surface to predicted suitability and clamps to a valid
range. The correction is typically defined only inside the AOA (see
`residual_krige`); `outside` controls what happens to cells with no
correction.

## Usage

``` r
apply_residual_correction(
  pred,
  correction,
  clamp = c(0, 1),
  outside = c("keep", "na")
)
```

## Arguments

- pred:

  A `SpatRaster` of predicted suitability.

- correction:

  A `SpatRaster` correction (resampled to `pred` if their grids differ),
  `NA` outside the AOA.

- clamp:

  Range to clamp the corrected values to (default `c(0, 1)`; `NULL` to
  skip).

- outside:

  What to do where `correction` is `NA`: `"keep"` the original
  prediction uncorrected (default), or `"na"` to blank those cells.

## Value

A `SpatRaster` of corrected suitability.

# Empirical variogram of point residuals, with an optional fitted model

Empirical variogram of point residuals, with an optional fitted model

## Usage

``` r
residual_variogram(
  points,
  resid = "resid",
  cutoff = NULL,
  width = NULL,
  model = "Exp",
  fit = TRUE,
  nugget_cut = 0.9
)
```

## Arguments

- points:

  An `sf` point layer carrying a residual column.

- resid:

  Name of the residual column (default `"resid"`).

- cutoff, width:

  Passed to
  [`variogram`](https://r-spatial.github.io/gstat/reference/variogram.html);
  defaults let gstat choose.

- model:

  Variogram model form for the fit, e.g. `"Exp"`, `"Sph"`.

- fit:

  Whether to fit `model` to the empirical variogram.

- nugget_cut:

  A field is flagged `pure_nugget` when the fitted nugget is at least
  this fraction of the total sill, or when the fit does not converge.

## Value

A list with `empirical` (the gstat variogram data frame), `model` (the
fitted model or `NULL`), `nugget`, `psill`, `range`, `nugget_ratio`,
`sample_var`, and `pure_nugget`.

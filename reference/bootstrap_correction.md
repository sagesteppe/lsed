# Bootstrap ensemble of the residual-kriging correction surface

Resamples the points with replacement `n` times, re-krige each draw onto
`newdata`, and summarise the ensemble. Duplicate coordinates from
resampling are jittered slightly so the kriging system stays
non-singular.

## Usage

``` r
bootstrap_correction(
  points,
  newdata,
  resid = "resid",
  model,
  n = 199,
  aoa = NULL,
  aoa_thresh = 1,
  jitter = 1,
  seed = NULL,
  cores = NULL,
  ...
)
```

## Arguments

- points:

  An `sf` point layer carrying a residual column.

- newdata:

  Prediction locations (`sf` points or a `SpatRaster`).

- resid:

  Name of the residual column (default `"resid"`).

- model:

  A fitted variogram model.

- n:

  Number of bootstrap resamples.

- aoa:

  Area-of-applicability restricting where the correction is produced (a
  DI `SpatRaster` or polygon; see `residual_krige`). `NULL` predicts
  everywhere.

- aoa_thresh:

  In-domain DI threshold for a raster `aoa` (default 1).

- jitter:

  Metres of jitter applied to resampled points to break ties.

- seed:

  Optional RNG seed. For `cores > 1` an L'Ecuyer-CMRG stream is used so
  the forked resamples are reproducible.

- cores:

  Worker processes for the resample loop, capped at `n`. Defaults to
  `getOption("mc.cores", 1L)` (serial unless you opt in). Uses
  [`mclapply`](https://rdrr.io/r/parallel/mclapply.html), which forks on
  Unix-alikes and degrades to serial on Windows.

- ...:

  Passed to
  [`krige`](https://r-spatial.github.io/gstat/reference/krige.html).

## Value

`newdata` (or a `SpatRaster`) with the ensemble mean `corr_mean` and
standard deviation `corr_sd` of the correction, restricted to `aoa`.

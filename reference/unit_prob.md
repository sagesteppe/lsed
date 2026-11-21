# Per-group probability summary (min / max / mean / n) from cell values

Grouped reduction over the per-cell probability values, returning the
minimum, maximum, **mean**, and cell count per group in one pass. The
mean is the plain unweighted cell mean – identical to
`terra::zonal(pr, id, "mean")` (terra's zonal mean is unweighted, and
the grid is equal-area, so this is also the area-weighted mean) – but it
is computed here directly from the values we already hold alongside min
and max, with no extra raster pass.

## Usage

``` r
unit_prob(val, grp)
```

## Arguments

- val:

  Numeric vector of per-cell probabilities.

- grp:

  Integer vector (same length) of group ids (unit or patch).

## Value

A data.frame with columns `id, prob_min, prob_max, prob_mean, n`, one
row per group, ordered by ascending id.

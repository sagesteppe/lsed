# Roll per-unit stats up to their parent patch

Aggregate the per-unit attribute table to one row per parent patch.
Patch stats are exact aggregates of their units' — min of the mins, max
of the maxes, n-weighted mean of the means, summed cell count — so an
un-split patch (a single unit) is a straight copy and no patch is
re-reduced from the cell values a second time. Acreage is recomputed
from the summed cell count.

## Usage

``` r
rollup_patches(ap, cell_area)
```

## Arguments

- ap:

  A per-unit data.frame with (at least) columns `patch`, `n`,
  `prob_min`, `prob_max`, `prob_mean` (e.g. the units table built in
  [`survey_units`](https://sagesteppe.github.io/lsed/reference/survey_units.md)).

- cell_area:

  Area of one cell (m^2).

## Value

A data.frame with columns
`patch, prob_min, prob_max, prob_mean, n, acres`, one row per patch,
ordered by ascending patch id.

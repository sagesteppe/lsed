# Reconstructed precision-recall curve from a binormal ROC at a prevalence

PR curve implied by an equal-variance binormal ROC (separation `mu`) at
prevalence `pi`. The point-level analogue of
[`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)
and the summary-metric counterpart of
[`pr_curve_exact`](https://sagesteppe.github.io/lsed/reference/pr_curve_exact.md).

## Usage

``` r
pr_curve_binormal(mu, pi, grid = 400)
```

## Arguments

- mu:

  Binormal separation (\>= 0).

- pi:

  Prevalence in (0, 1).

- grid:

  Number of recall points on the curve.

## Value

`data.frame` with columns `recall` and `precision`.

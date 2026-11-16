# Exact precision-recall curve at a target prevalence

Full PR curve from point-level predictions, case-weighted to prevalence
`pi` with
[`reweight`](https://sagesteppe.github.io/lsed/reference/reweight.md).
The point-level analogue of
[`ap_pointwise`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md)
(which integrates this curve).

## Usage

``` r
pr_curve_exact(truth, prob, pi)
```

## Arguments

- truth:

  Outcomes coded 1 / 0.

- prob:

  Predicted probabilities/scores.

- pi:

  Target prevalence in (0, 1).

## Value

`data.frame` with columns `recall` and `precision`, ordered by
descending score.

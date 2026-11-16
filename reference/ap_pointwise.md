# Exact per-point average precision (PR-AUC) at a target prevalence

Average precision computed directly from point-level predictions,
case-weighted to a target landscape prevalence with
[`reweight`](https://sagesteppe.github.io/lsed/reference/reweight.md).
Recall is prevalence-invariant; precision is not, so re-pricing the
weights re-prices the PR curve. This is the exact route, used whenever
the full `(truth, prob)` pairs are available.

## Usage

``` r
ap_pointwise(truth, prob, pi)
```

## Arguments

- truth:

  Outcomes coded 1 (presence) / 0 (absence).

- prob:

  Predicted probabilities (or any score), same length as `truth`.

- pi:

  Target landscape prevalence in (0, 1).

## Value

Scalar average precision, or `NA_real_` if a class is absent.

## See also

[`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)
for the summary-metric counterpart.

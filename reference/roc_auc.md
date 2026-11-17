# ROC-AUC via the rank (Mann-Whitney) identity

Area under the ROC curve computed from the rank-sum of the positive
scores, equivalent to the probability that a random presence outscores a
random absence. Prevalence-invariant, so no case weighting is needed.

## Usage

``` r
roc_auc(truth, prob)
```

## Arguments

- truth:

  Outcomes coded 1 (presence) / 0 (absence).

- prob:

  Predicted probabilities or scores, same length as `truth`.

## Value

Scalar ROC-AUC, or `NA_real_` if a class is absent.

## Note

ROC-AUC is a discrimination *diagnostic* – the probability a random
presence outscores a random absence – not a decision-curve
reconstruction anchor. On species-distribution models it is easily
inflated by easy, far-from-suitable absences the model rejects for free,
so a curve rebuilt from it can oversell and disappoint on
ground-truthing. To reconstruct a prevalence-corrected decision curve,
anchor on a PR-AUC
([`pr_auc`](https://sagesteppe.github.io/lsed/reference/pr_auc.md)) and
pass it to
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)
or
[`nb_binormal_band`](https://sagesteppe.github.io/lsed/reference/nb_binormal_band.md).

## See also

[`pr_auc`](https://sagesteppe.github.io/lsed/reference/pr_auc.md) (the
precision diagnostic),
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md),
[`nb_binormal_band`](https://sagesteppe.github.io/lsed/reference/nb_binormal_band.md).

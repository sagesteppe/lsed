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

# Reported precision-recall AUC (average precision) at the sample prevalence

Average precision computed at the evaluation sample's own prevalence –
the ordinary (unweighted) PR-AUC a model reports from its test set, and
the precision-side sibling of the prevalence-invariant
[`roc_auc`](https://sagesteppe.github.io/lsed/reference/roc_auc.md). It
is exactly
[`ap_pointwise`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md)
evaluated at `pi = mean(truth == 1)` (where the prevalence weights
become uniform); use
[`ap_pointwise`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md)
directly to re-price average precision to a different target prevalence.

## Usage

``` r
pr_auc(truth, prob)
```

## Arguments

- truth:

  Outcomes coded 1 (presence) / 0 (absence).

- prob:

  Predicted probabilities or scores, same length as `truth`.

## Value

Scalar average precision at the sample prevalence, or `NA_real_` if a
class is absent.

## Note

Unlike
[`roc_auc`](https://sagesteppe.github.io/lsed/reference/roc_auc.md),
average precision is not inflated by easy absences, which is why it is
the recommended anchor for curve reconstruction. This function is still
a per-sample *diagnostic*: to rebuild a prevalence-corrected decision
curve, pass the reported value – together with the prevalence it was
measured at – to
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)
or
[`nb_binormal_band`](https://sagesteppe.github.io/lsed/reference/nb_binormal_band.md).

## See also

[`roc_auc`](https://sagesteppe.github.io/lsed/reference/roc_auc.md) (the
discrimination diagnostic),
[`ap_pointwise`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md)
(re-price to a target prevalence),
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md),
[`nb_binormal_band`](https://sagesteppe.github.io/lsed/reference/nb_binormal_band.md).

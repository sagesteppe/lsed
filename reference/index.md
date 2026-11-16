# Package index

## Prevalence weighting

Re-price an evaluation sample to a target landscape prevalence.

- [`reweight()`](https://sagesteppe.github.io/lsed/reference/reweight.md)
  : Prevalence case weights

## Discrimination

Prevalence-invariant ranking performance.

- [`roc_auc()`](https://sagesteppe.github.io/lsed/reference/roc_auc.md)
  : ROC-AUC via the rank (Mann-Whitney) identity

## Average precision & PR curves

Precision-recall at a target prevalence, by the exact point-level route
and the equal-variance binormal (summary-metric) route.

- [`ap_pointwise()`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md)
  : Exact per-point average precision (PR-AUC) at a target prevalence
- [`ap_binormal()`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)
  : Average precision of an equal-variance binormal ROC at a prevalence
- [`ap_scalar_to_prev()`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)
  : Correct a scalar PR-AUC from its design prevalence to a target
  prevalence
- [`pr_curve_exact()`](https://sagesteppe.github.io/lsed/reference/pr_curve_exact.md)
  : Exact precision-recall curve at a target prevalence
- [`pr_curve_binormal()`](https://sagesteppe.github.io/lsed/reference/pr_curve_binormal.md)
  : Reconstructed precision-recall curve from a binormal ROC at a
  prevalence

## Net benefit (decision curves)

Decision-curve net benefit and its reference strategies.

- [`nb_exact()`](https://sagesteppe.github.io/lsed/reference/nb_exact.md)
  : Net benefit of thresholded predictions at a target prevalence
- [`nb_binormal()`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md)
  : Best-achievable net benefit from an equal-variance binormal ROC
- [`nb_treat_all()`](https://sagesteppe.github.io/lsed/reference/nb_treat_all.md)
  : Net benefit of the treat-all (survey-everything) reference strategy

## Calibration

Assess and shift the calibration of held-out predictions.

- [`cox_calibration()`](https://sagesteppe.github.io/lsed/reference/cox_calibration.md)
  : Cox calibration intercept and slope on held-out predictions
- [`recalibrate_to_prevalence()`](https://sagesteppe.github.io/lsed/reference/recalibrate_to_prevalence.md)
  : Recalibrate predicted probabilities to a target prevalence (logit
  shift)
- [`clamp()`](https://sagesteppe.github.io/lsed/reference/clamp.md) :
  Clamp probabilities away from 0 and 1

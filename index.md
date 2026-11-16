# lsed

Prevalence-corrected evaluation of species-distribution model
predictions — the metric helpers behind the decision-curve manuscript.

## Install

``` r

# from the package root
devtools::install(".")
# or
# R CMD INSTALL .
```

## What’s here

| Function | Purpose |
|----|----|
| [`reweight()`](https://sagesteppe.github.io/lsed/reference/reweight.md) | Case weights that re-price an evaluation sample to a target prevalence |
| [`roc_auc()`](https://sagesteppe.github.io/lsed/reference/roc_auc.md) | Prevalence-invariant ROC-AUC via the rank (Mann-Whitney) identity |
| [`ap_pointwise()`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md), [`pr_curve_exact()`](https://sagesteppe.github.io/lsed/reference/pr_curve_exact.md) | Exact average precision / PR curve at a target prevalence |
| [`ap_binormal()`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md), [`pr_curve_binormal()`](https://sagesteppe.github.io/lsed/reference/pr_curve_binormal.md), [`ap_scalar_to_prev()`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md) | Equal-variance binormal (summary-metric) route |
| [`nb_exact()`](https://sagesteppe.github.io/lsed/reference/nb_exact.md), [`nb_binormal()`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md), [`nb_treat_all()`](https://sagesteppe.github.io/lsed/reference/nb_treat_all.md) | Decision-curve net benefit (per-point, best-achievable, treat-all) |
| [`cox_calibration()`](https://sagesteppe.github.io/lsed/reference/cox_calibration.md), [`recalibrate_to_prevalence()`](https://sagesteppe.github.io/lsed/reference/recalibrate_to_prevalence.md), [`clamp()`](https://sagesteppe.github.io/lsed/reference/clamp.md) | Calibration helpers |

`data-raw/logo.R` regenerates the hex sticker (`man/figures/logo.png`);
it is a development script and is not installed with the package.

# lsed

Prevalence-corrected evaluation of species-distribution model predictions —
the metric helpers behind the decision-curve manuscript.

## Install

```r
# from the package root
devtools::install(".")
# or
# R CMD INSTALL .
```

## What's here

| Function | Purpose |
|---|---|
| `reweight()` | Case weights that re-price an evaluation sample to a target prevalence |
| `roc_auc()` | Prevalence-invariant ROC-AUC via the rank (Mann-Whitney) identity |
| `ap_pointwise()`, `pr_curve_exact()` | Exact average precision / PR curve at a target prevalence |
| `ap_binormal()`, `pr_curve_binormal()`, `ap_scalar_to_prev()` | Equal-variance binormal (summary-metric) route |
| `nb_exact()`, `nb_binormal()`, `nb_treat_all()` | Decision-curve net benefit (per-point, best-achievable, treat-all) |
| `cox_calibration()`, `recalibrate_to_prevalence()`, `clamp()` | Calibration helpers |

`data-raw/logo.R` regenerates the hex sticker (`man/figures/logo.png`); it is a
development script and is not installed with the package.

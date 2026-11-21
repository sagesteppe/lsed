# lsed

[![lsed package hexagonal
logo](reference/figures/logo.png)](https://sagesteppe.github.io/lsed/)

A software package (R and Python) for determining the benefit of using a
statistical model in landscape decision making. Currently using minor
extensions of decision curve analysis (DCA), geared towards species
distribution models.

## Overview

boop boop.

## Installation

lsed is available only on github, with plans for submission to CRAN. It
can be installed using `remotes` or `devtools` (or `pak` etc.):

``` r

install.packages('remotes')
remotes::install_github('sagesteppe/lsed')
```

## Functions

| Function | Purpose |
|----|----|
| [`reweight()`](https://sagesteppe.github.io/lsed/reference/reweight.md) | Case weights that re-price an evaluation sample to a target prevalence |
| [`roc_auc()`](https://sagesteppe.github.io/lsed/reference/roc_auc.md) | Prevalence-invariant ROC-AUC via the rank (Mann-Whitney) identity |
| [`ap_pointwise()`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md), [`pr_curve_exact()`](https://sagesteppe.github.io/lsed/reference/pr_curve_exact.md) | Exact average precision / PR curve at a target prevalence |
| [`ap_binormal()`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md), [`pr_curve_binormal()`](https://sagesteppe.github.io/lsed/reference/pr_curve_binormal.md), [`ap_scalar_to_prev()`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md) | Equal-variance binormal (summary-metric) route |
| [`nb_exact()`](https://sagesteppe.github.io/lsed/reference/nb_exact.md), [`nb_binormal()`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md), [`nb_treat_all()`](https://sagesteppe.github.io/lsed/reference/nb_treat_all.md) | Decision-curve net benefit (per-point, best-achievable, treat-all) |
| [`cox_calibration()`](https://sagesteppe.github.io/lsed/reference/cox_calibration.md), [`recalibrate_to_prevalence()`](https://sagesteppe.github.io/lsed/reference/recalibrate_to_prevalence.md), [`clamp()`](https://sagesteppe.github.io/lsed/reference/clamp.md) | Calibration helpers |
| [`survey_units()`](https://sagesteppe.github.io/lsed/reference/survey_units.md) | Convert a continuous raster into survey units |

## Citation

Benkendorf, R.C. 2026. lsed

A bibtex entry for latex users is:

@Misc{benkendorf2026lsed,  
title = {lsed},  
author = {Benkendorf R.C.},  
year = {2026},  
url = {<https://github.com/sagesteppe/lsed>} }

Or use R to display citations:

``` r

citation('lsed')
```

For complete citation information, see the [citation
page](https://sagesteppe.github.io/lsed/authors.html#citation).

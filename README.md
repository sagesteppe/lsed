<!-- SEO Meta Tags -->

<meta name="description" content="A software package (R, and Python) for determining the benefit of using a statistical model in landscape decision making. 
Currently using minor extensions of decision curve analysis (dca), geared towards species distribution models. 
">

# lsed

<a href="https://sagesteppe.github.io/lsed/"><img src="man/figures/logo.png" align="right" height="138" alt="lsed package hexagonal logo" /></a>

<!-- badges: start -->

[![CRAN
checks](https://badges.cranchecks.info/summary/badger.svg)](https://cran.r-project.org/web/checks/check_results_badger.html)
[![R build
status](https://github.com/sagesteppe/lsed/workflows/R-CMD-check/badge.svg)](https://github.com/sagesteppe/lsed/actions)
[![CodeFactor](https://www.codefactor.io/repository/github/sagesteppe/lsed/badge)](https://www.codefactor.io/repository/github/sagesteppe/lsed)
[![Project Status: Active - The project has reached a stable, usable
state and is being actively
developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![](https://codecov.io/gh/sagesteppe/lsed/branch/main/graph/badge.svg)](https://app.codecov.io/gh/sagesteppe/lsed)

<!-- badges: end -->

A software package (R, and Python) for determining the benefit of using
a statistical model in landscape decision making. Currently using minor
extensions of decision curve analysis (dca), geared towards species
distribution models.

## Overview

boop boop.

## Installation

lsed is available only on github, with plans for submission to CRAN. It
can be installed using `remotes` or `devtools` (or `pak` etc.) like so:

``` r
install.packages('devtools')
devtools::install_github('sagesteppe/eSTZwritR')
```

## Functions

| Function                                                      | Purpose                                                                |
| ------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `reweight()`                                                  | Case weights that re-price an evaluation sample to a target prevalence |
| `roc_auc()`                                                   | Prevalence-invariant ROC-AUC via the rank (Mann-Whitney) identity      |
| `ap_pointwise()`, `pr_curve_exact()`                          | Exact average precision / PR curve at a target prevalence              |
| `ap_binormal()`, `pr_curve_binormal()`, `ap_scalar_to_prev()` | Equal-variance binormal (summary-metric) route                         |
| `nb_exact()`, `nb_binormal()`, `nb_treat_all()`               | Decision-curve net benefit (per-point, best-achievable, treat-all)     |
| `cox_calibration()`, `recalibrate_to_prevalence()`, `clamp()` | Calibration helpers                                                    |

## Citation

Benkendorf, R.C. 2024. lsed

A bibtex entry for latex users is:

@Misc{benkendorf2026lsed,  
title = {lsed},  
author = {Benkendorf R.C.},  
year = {2026},  
url = {<https://github.com/sagesteppe/lsed>},  
\#\#doi = {10.5281/zenodo.14641975} }

Or use R to display citations:

``` r
citation('eSTZwritR')
```

For complete citation information, see the [citation
page](authors.html#citation).

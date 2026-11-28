# lsed

[![lsed package hexagonal
logo](reference/figures/logo.png)](https://sagesteppe.github.io/lsed/)

A software package ([R](https://github.com/sagesteppe/lsed) and
[Python](https://github.com/sagesteppe/lsed-py)) for determining the
benefit of using a statistical model in landscape decision making.
Currently using minor extensions of decision curve analysis (DCA),
geared towards species distribution models.

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

The package splits into two toolkits: **DCA Support** (the
prevalence-corrected evaluation of species-distribution predictions) and
**Prioritisation** (building a `RankIndex` to prioritise sites for
survey). Each function links to its reference page.

### DCA Support

| Function | Purpose |
|----|----|
| [`reweight()`](https://sagesteppe.github.io/lsed/reference/reweight.html) | Case weights that re-price an evaluation sample to a target prevalence |
| [`roc_auc()`](https://sagesteppe.github.io/lsed/reference/roc_auc.html) | Prevalence-invariant ROC-AUC via the rank (Mann-Whitney) identity |
| [`ap_pointwise()`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.html), [`pr_curve_exact()`](https://sagesteppe.github.io/lsed/reference/pr_curve_exact.html), [`pr_auc()`](https://sagesteppe.github.io/lsed/reference/pr_auc.html) | Exact average precision / PR curve / PR-AUC at a target prevalence |
| [`ap_binormal()`](https://sagesteppe.github.io/lsed/reference/ap_binormal.html), [`pr_curve_binormal()`](https://sagesteppe.github.io/lsed/reference/pr_curve_binormal.html), [`ap_scalar_to_prev()`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.html) | Equal-variance binormal (summary-metric) route |
| [`nb_exact()`](https://sagesteppe.github.io/lsed/reference/nb_exact.html), [`nb_exact_ci()`](https://sagesteppe.github.io/lsed/reference/nb_exact_ci.html), [`nb_binormal()`](https://sagesteppe.github.io/lsed/reference/nb_binormal.html), [`nb_binormal_band()`](https://sagesteppe.github.io/lsed/reference/nb_binormal_band.html), [`nb_treat_all()`](https://sagesteppe.github.io/lsed/reference/nb_treat_all.html) | Decision-curve net benefit (per-point, CI, binormal, uncertainty band, treat-all) |
| [`cox_calibration()`](https://sagesteppe.github.io/lsed/reference/cox_calibration.html), [`recalibrate_to_prevalence()`](https://sagesteppe.github.io/lsed/reference/recalibrate_to_prevalence.html), [`clamp()`](https://sagesteppe.github.io/lsed/reference/clamp.html) | Calibration of held-out predictions |
| [`point_residuals()`](https://sagesteppe.github.io/lsed/reference/point_residuals.html), [`reduce_spatial_bias()`](https://sagesteppe.github.io/lsed/reference/reduce_spatial_bias.html) | Residual-kriging correction of spatially-structured prediction bias within the area of applicability |

A vignette for these functions is located at [Prevalence-corrected
evaluation in two
routes](https://sagesteppe.github.io/lsed/articles/lsed.html).

A vignette for these functions is located at [Prevalence-corrected
evaluation in two
routes](https://sagesteppe.github.io/lsed/articles/lsed.html).

### Prioritisation

| Function | Purpose |
|----|----|
| [`rank_download()`](https://sagesteppe.github.io/lsed/reference/rank_download.html) | One-call acquisition of every external input (GBIF records + OSM network) |
| [`gbif_records()`](https://sagesteppe.github.io/lsed/reference/gbif_records.html), [`gbif_request()`](https://sagesteppe.github.io/lsed/reference/gbif_request.html), [`gbif_retrieve()`](https://sagesteppe.github.io/lsed/reference/gbif_retrieve.html) | Pull target-group occurrence records from GBIF |
| [`osm_access()`](https://sagesteppe.github.io/lsed/reference/osm_access.html), [`osm_network_for()`](https://sagesteppe.github.io/lsed/reference/osm_network_for.html) | Fetch the OpenStreetMap road / trail network |
| [`survey_units()`](https://sagesteppe.github.io/lsed/reference/survey_units.html) | Delineate survey units from a continuous suitability raster |
| [`survey_surface()`](https://sagesteppe.github.io/lsed/reference/survey_surface.html), [`survey_weights()`](https://sagesteppe.github.io/lsed/reference/survey_weights.html), [`guess_record_type()`](https://sagesteppe.github.io/lsed/reference/guess_record_type.html) | Survey-intensity (bias) surface - the S term |
| [`geo_distance()`](https://sagesteppe.github.io/lsed/reference/geo_distance.html) | Geographic distance to known populations - the Dg term |
| [`build_resistance()`](https://sagesteppe.github.io/lsed/reference/build_resistance.html), [`cost_distance()`](https://sagesteppe.github.io/lsed/reference/cost_distance.html), [`tobler_friction()`](https://sagesteppe.github.io/lsed/reference/tobler_friction.html), [`cluster_region_extents()`](https://sagesteppe.github.io/lsed/reference/cluster_region_extents.html) | Isotropic cost-distance engine - Dr / A terms |
| [`build_network()`](https://sagesteppe.github.io/lsed/reference/build_network.html), [`contract_network()`](https://sagesteppe.github.io/lsed/reference/contract_network.html), [`accessibility()`](https://sagesteppe.github.io/lsed/reference/accessibility.html), [`complementarity()`](https://sagesteppe.github.io/lsed/reference/complementarity.html) | Network travel-time engine - A / C terms |
| [`osm_speeds`](https://sagesteppe.github.io/lsed/reference/osm_speeds.html) | Default per-highway travel speeds (km/h) |
| [`cluster_patches()`](https://sagesteppe.github.io/lsed/reference/cluster_patches.html) | Group nearby patches into spatial clusters |
| [`rank_index()`](https://sagesteppe.github.io/lsed/reference/rank_index.html), [`rank_calculate()`](https://sagesteppe.github.io/lsed/reference/rank_calculate.html) | Combine the terms into a priority score and ranking |

A vignette for these functions is located at [Prioritising sites for
survey
(RankIndex)](https://sagesteppe.github.io/lsed/articles/prioritisation.html).
Where you will, hopefully, happily see you only *need* to run two of
them.

A vignette for these functions is located at [Prioritising sites for
survey
(RankIndex)](https://sagesteppe.github.io/lsed/articles/prioritisation.html).
Where you will, hopefully, happily see you only *need* to run two of
them.

## Citation

Benkendorf, R.C. 2026. lsed

A BibTeX entry for LaTeX users is
[here](https://sagesteppe.github.io/lsed/authors.html#citation).

Or use R to display citations:

``` r

citation('lsed')
```

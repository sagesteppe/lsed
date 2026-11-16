# Correct a scalar PR-AUC from its design prevalence to a target prevalence

Given a reported PR-AUC measured at design prevalence `pi0`, recover the
equal-variance binormal ROC that reproduces it
([`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)),
then re-integrate precision at `pi_target`. Use when only a summary
PR-AUC and the prevalence it was measured at are available.

## Usage

``` r
ap_scalar_to_prev(pr_auc, pi0, pi_target, grid = 20000)
```

## Arguments

- pr_auc:

  Reported PR-AUC (average precision) at the design prevalence.

- pi0:

  Design/evaluation prevalence the `pr_auc` was measured at.

- pi_target:

  Target landscape prevalence to re-price to.

- grid:

  Number of recall points passed to
  [`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md).

## Value

List with `ap_target` (PR-AUC at `pi_target`), the fitted `mu`, and the
`implied_roc_auc` = `pnorm(mu / sqrt(2))`.

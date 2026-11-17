# Plausibility band for a binormal net-benefit curve from PR-AUC uncertainty

The summary route
([`nb_binormal`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md))
anchors an entire decision curve to a single reported PR-AUC, almost
always a point estimate with no stated uncertainty. This propagates a
plausible *spread* in that PR-AUC into a band on the net-benefit curve,
extending
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)
from a point reconstruction to an interval one.

## Usage

``` r
nb_binormal_band(
  pr_auc,
  pi,
  pt,
  spread,
  side = c("lower", "both"),
  pi0 = pi,
  grid = 3000
)
```

## Arguments

- pr_auc:

  Reported PR-AUC (average precision) at the evaluation prevalence, a
  single value.

- pi:

  Target landscape prevalence in (0, 1).

- pt:

  Numeric vector of threshold probabilities.

- spread:

  Half-width of the plausible PR-AUC range, in PR-AUC units (e.g. `0.04`
  for +/- 0.04). Calibrate from replicate-model spread.

- side:

  `"lower"` (default) for a one-sided lower band, or `"both"` for lower
  and upper edges.

- pi0:

  Evaluation prevalence the PR-AUC was measured at. Defaults to `pi`.

- grid:

  Integration grid passed to
  [`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)
  when inverting the PR-AUC.

## Value

A data frame with one row per `pt`: `pt`, the central curve `nb`, and
`lower` (plus `upper` when `side = "both"`). The fitted separations are
attached as attribute `"mu"` (named `central`, `lower`, and `upper` when
two-sided).

## Details

The perturbation is anchored on the PR-AUC scale, not on `mu` directly:
a fixed shift in `mu` has no stable meaning across taxa or prevalences,
whereas a spread in PR-AUC is what replicate train/test partitions
actually show. The reported PR-AUC and its `spread`-perturbed endpoints
are each converted to a binormal separation by inverting
[`ap_binormal`](https://sagesteppe.github.io/lsed/reference/ap_binormal.md)
at the evaluation prevalence `pi0`, then read off
[`nb_binormal`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md)
at the target prevalence. Because `nb_binormal` is monotone increasing
in `mu`, the PR-AUC endpoints map straight to the band edges.

This is a *plausibility* band (a sensitivity analysis over an assumed
PR-AUC spread), not a confidence interval: with only a reported scalar
there is no sampling distribution. Calibrate `spread` from replicate
models when you have them; see
[`nb_exact_ci`](https://sagesteppe.github.io/lsed/reference/nb_exact_ci.md)
for the model-free sampling band when raw predictions are available.

Only a *lower* band is returned by default, matching
[`nb_exact_ci`](https://sagesteppe.github.io/lsed/reference/nb_exact_ci.md):
in decision-curve analysis the decision-relevant uncertainty is the
downside – whether the model could be worse than a default strategy. Use
`side = "both"` for upper and lower edges.

## See also

[`nb_binormal`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md),
[`nb_exact_ci`](https://sagesteppe.github.io/lsed/reference/nb_exact_ci.md),
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)

# Recalibrate predicted probabilities to a target prevalence (logit shift)

Shift predictions on the logit scale from their observed prevalence
`p_obs` to a target prevalence `pi`, leaving relative ordering intact:
`plogis(logit(prob) - logit(p_obs) + logit(pi))`. Inputs are clamped
with [`clamp`](https://sagesteppe.github.io/lsed/reference/clamp.md) to
keep the logits finite.

## Usage

``` r
recalibrate_to_prevalence(prob, p_obs, pi)
```

## Arguments

- prob:

  Predicted probabilities.

- p_obs:

  Prevalence the predictions were produced at.

- pi:

  Target landscape prevalence in (0, 1).

## Value

Numeric vector of recalibrated probabilities.

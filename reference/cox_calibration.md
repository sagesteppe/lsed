# Cox calibration intercept and slope on held-out predictions

Cox (logistic) calibration of predicted probabilities against observed
outcomes. The slope comes from `glm(truth ~ logit(prob))`; the intercept
("calibration-in-the-large") from
`glm(truth ~ 1, offset = logit(prob))`. Separated or non-converging fits
(\|coef\| \>= 15) are dropped to `NA`.

## Usage

``` r
cox_calibration(truth, prob)
```

## Arguments

- truth:

  Outcomes coded 1 / 0.

- prob:

  Predicted probabilities.

## Value

Named numeric vector `c(cox_intercept, cox_slope)`; either entry may be
`NA_real_`.

# Clamp probabilities away from 0 and 1

Bound probabilities into `[eps, 1 - eps]` so that logit transforms stay
finite. Used by the calibration helpers before
[`qlogis`](https://rdrr.io/r/stats/Logistic.html).

## Usage

``` r
clamp(p, eps = 1e-06)
```

## Arguments

- p:

  Numeric vector of probabilities.

- eps:

  Small margin; values are clamped to `[eps, 1 - eps]`.

## Value

Numeric vector the same length as `p`.

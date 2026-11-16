# Average precision of an equal-variance binormal ROC at a prevalence

Average precision implied by an equal-variance binormal ROC with
separation `mu` (so `TPR = pnorm(qnorm(FPR) + mu)`), integrated at
prevalence `pi` by the trapezoid rule. This is the summary-metric route:
pair it with
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md)
to turn a single reported PR-AUC into a full, prevalence-corrected PR
curve shape.

## Usage

``` r
ap_binormal(mu, pi, grid = 4000)
```

## Arguments

- mu:

  Binormal separation (\>= 0). Larger `mu` = better discrimination.

- pi:

  Prevalence in (0, 1) at which to price precision.

- grid:

  Number of recall points for the trapezoid integral.

## Value

Scalar average precision.

## See also

[`ap_pointwise`](https://sagesteppe.github.io/lsed/reference/ap_pointwise.md),
[`ap_scalar_to_prev`](https://sagesteppe.github.io/lsed/reference/ap_scalar_to_prev.md).

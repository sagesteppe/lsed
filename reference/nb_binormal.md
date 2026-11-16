# Best-achievable net benefit from an equal-variance binormal ROC

Net benefit read off an equal-variance binormal ROC (separation `mu`) at
the operating point whose slope equals the cost ratio
`((1 - pi) / pi) * (pt / (1 - pt))`. Because it always uses the optimal
cutoff, this is the calibration-*independent*, best-achievable net
benefit for that ROC – the summary-metric counterpart of
[`nb_exact`](https://sagesteppe.github.io/lsed/reference/nb_exact.md).

## Usage

``` r
nb_binormal(mu, pi, pt)
```

## Arguments

- mu:

  Binormal separation (\>= 0).

- pi:

  Target landscape prevalence in (0, 1).

- pt:

  Numeric vector of threshold probabilities.

## Value

Numeric vector of net benefit, one per element of `pt`.

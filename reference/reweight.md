# Prevalence case weights

Case weights that re-price an evaluation sample to a target landscape
prevalence. Every presence receives weight `pi / n1` and every absence
`(1 - pi) / n0`, so the total presence weight is `pi`, the total absence
weight is `1 - pi`, and the weights sum to 1. Thresholded summaries
(recall, precision, net benefit) computed with these weights behave as
if the sample had been drawn at prevalence `pi`.

## Usage

``` r
reweight(truth, pi)
```

## Arguments

- truth:

  Integer/numeric vector of outcomes coded 1 (presence) / 0 (absence).

- pi:

  Target landscape prevalence in (0, 1).

## Value

Numeric vector of weights, the same length as `truth`.

## Examples

``` r
w <- reweight(c(1, 0, 0, 1), pi = 0.05)
sum(w)            # 1
#> [1] 1
sum(w[c(1, 0, 0, 1) == 1])  # 0.05
#> [1] 0.05
```

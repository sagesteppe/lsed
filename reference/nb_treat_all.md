# Net benefit of the treat-all (survey-everything) reference strategy

The decision-curve reference that acts on every unit:
`pi - (1 - pi) * (pt / (1 - pt))`. Treat-none is identically 0.

## Usage

``` r
nb_treat_all(pi, pt)
```

## Arguments

- pi:

  Prevalence in (0, 1).

- pt:

  Numeric vector of threshold probabilities.

## Value

Numeric vector of net benefit, one per element of `pt`.

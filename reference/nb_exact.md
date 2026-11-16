# Net benefit of thresholded predictions at a target prevalence

Decision-curve net benefit of treating (surveying) every unit whose
predicted probability is at least the threshold `pt`, case-weighted to a
target landscape prevalence with
[`reweight`](https://sagesteppe.github.io/lsed/reference/reweight.md):
\$\$NB(p_t) = TP_w - FP_w \cdot \frac{p_t}{1 - p_t},\$\$ where \\TP_w\\
and \\FP_w\\ are the prevalence-weighted true- and false-positive
fractions. This is the calibration-*dependent* (per-point) route: it
thresholds the probabilities as given.

## Usage

``` r
nb_exact(truth, prob, pi, pt)
```

## Arguments

- truth:

  Outcomes coded 1 (presence) / 0 (absence).

- prob:

  Predicted probabilities, same length as `truth`.

- pi:

  Target landscape prevalence in (0, 1).

- pt:

  Numeric vector of threshold probabilities.

## Value

Numeric vector of net benefit, one per element of `pt`.

## See also

[`nb_binormal`](https://sagesteppe.github.io/lsed/reference/nb_binormal.md)
(best-achievable from an ROC),
[`nb_treat_all`](https://sagesteppe.github.io/lsed/reference/nb_treat_all.md)
(the treat-all reference).

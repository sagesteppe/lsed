# Bootstrap confidence band for the exact net-benefit curve

Percentile bootstrap confidence limits for
[`nb_exact`](https://sagesteppe.github.io/lsed/reference/nb_exact.md),
following the extensions of Vickers et al. (2008). Resampling is
*stratified by outcome* by default: presences and absences are resampled
with replacement separately so \\n_1\\ and \\n_0\\ – and therefore the
prevalence case weights
([`reweight`](https://sagesteppe.github.io/lsed/reference/reweight.md))
– stay fixed. This keeps the interval consistent with the
prevalence-invariant estimand, propagating only the sampling noise in
the within-class positive rates rather than in the sample's own
prevalence.

## Usage

``` r
nb_exact_ci(
  truth,
  prob,
  pi,
  pt,
  B = 999,
  level = 0.8,
  side = c("lower", "both"),
  stratified = TRUE,
  cores = NULL
)
```

## Arguments

- truth:

  Outcomes coded 1 (presence) / 0 (absence).

- prob:

  Predicted probabilities, same length as `truth`. These are assumed
  honest (held-out or cross-validated); the band quantifies precision,
  not optimism, and applies no overfit correction.

- pi:

  Target landscape prevalence in (0, 1).

- pt:

  Numeric vector of threshold probabilities.

- B:

  Number of bootstrap replicates. Default 999.

- level:

  Confidence level. Default 0.8.

- side:

  `"lower"` (default) for a one-sided lower band, or `"both"` for a
  two-sided interval.

- stratified:

  Resample within outcome classes (default `TRUE`) or over all
  observations (`FALSE`).

- cores:

  Number of worker processes, capped at `B`. Defaults to
  `getOption("mc.cores", 1L)`, i.e. serial unless you opt in. Parallel
  replicates use [`mclapply`](https://rdrr.io/r/parallel/mclapply.html),
  which forks on Unix-alikes only; on Windows, and in core-limited
  environments such as `R CMD check` and vignette knitting, execution
  falls back to serial (or at most two cores) regardless of this
  argument.

## Value

A data frame with one row per `pt`: the threshold `pt`, the point
estimate `nb`, and `lower` (plus `upper` when `side = "both"`).

## Details

Only a *lower* band is returned by default. In decision-curve analysis
the operative question is whether the model is at least as good as the
best default strategy (treat-all or treat-none), so the
decision-relevant uncertainty is the downside; an upper limit changes no
decision. Use `side = "both"` for a two-sided interval.

Bootstrap replicates are evaluated with
[`mclapply`](https://rdrr.io/r/parallel/mclapply.html), which forks on
Unix-alikes and falls back to serial execution on Windows. For
reproducible parallel runs set `RNGkind("L'Ecuyer-CMRG")` and a seed
before calling.

## References

Vickers AJ, Cronin AM, Elkin EB, Gonen M (2008). Extensions to decision
curve analysis, a novel method for evaluating diagnostic tests,
prediction models and molecular markers. *BMC Med Inform Decis Mak*
8:53.

## See also

[`nb_exact`](https://sagesteppe.github.io/lsed/reference/nb_exact.md)

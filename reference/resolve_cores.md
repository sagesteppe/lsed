# Resolve a worker-process count for forked parallelism

Shared helper for the bootstrap routines
([`nb_exact_ci`](https://sagesteppe.github.io/lsed/reference/nb_exact_ci.md),
`bootstrap_correction`). Defaults a `NULL` request to
`getOption("mc.cores", 1L)`, caps it at the number of independent jobs,
forces serial on Windows
([`mclapply`](https://rdrr.io/r/parallel/mclapply.html) cannot fork
there) and honours `_R_CHECK_LIMIT_CORES_` (set during R CMD check and
vignette knitting), which caps usable cores at 2.

## Usage

``` r
resolve_cores(cores, cap)
```

## Arguments

- cores:

  Requested worker count, or `NULL` to read `getOption("mc.cores", 1L)`.

- cap:

  Upper bound on the count (the number of independent jobs).

## Value

An integer worker count, at least 1.

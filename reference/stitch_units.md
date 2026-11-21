# Stitch per-patch local unit labels into one globally-numbered vector

Each patch's worker returns labels `1..k_i` local to that patch; this
offsets them by the running total so the final ids are `1..N` in patch
order – identical whatever order the workers finished in.

## Usage

``` r
stitch_units(groups, labs, n)
```

## Arguments

- groups:

  List of per-patch cell positions (as passed to
  [`papply`](https://sagesteppe.github.io/lsed/reference/papply.md)).

- labs:

  List of per-patch local label vectors (from
  [`papply`](https://sagesteppe.github.io/lsed/reference/papply.md)).

- n:

  Length of the output (number of suitable cells).

## Value

Integer vector of global unit ids, length `n`.

# Apply a per-patch function over patch groups, optionally in parallel

Runs `fn` over the elements of `groups` (one per patch) with
[`mclapply`](https://rdrr.io/r/parallel/mclapply.html) when `cores > 1`,
else `lapply`. mclapply forks (copy-on-write), so the big shared vectors
are not serialised; on Windows `cores > 1` degrades to serial
automatically. Output order always matches input order, so results stay
deterministic regardless of cores.

## Usage

``` r
papply(groups, fn, cores = 1)
```

## Arguments

- groups:

  A list (e.g. from `split`) of per-patch cell positions.

- fn:

  A function of one group element returning that patch's local labels.

- cores:

  Integer worker count (`1` = serial).

## Value

A list the same length/order as `groups`.

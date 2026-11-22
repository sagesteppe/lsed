# Resistance / accessibility distance by isotropic cost distance (Dr, A)

Accumulated least-cost distance from `sources` over a `friction` surface
([`costDist`](https://rspatial.github.io/terra/reference/costDist.html)),
rescaled to \\\[0, 1\]\\. Sources are burned into the friction as
zero-cost targets. With `tile = TRUE` the work is split into buffered
regions around source clusters
([`cluster_region_extents`](https://sagesteppe.github.io/lsed/reference/cluster_region_extents.md))
and mosaicked by minimum cost, keeping large domains in memory; the
buffer and the min-mosaic absorb tile-edge effects.

## Usage

``` r
cost_distance(
  friction,
  sources,
  template = friction,
  tile = FALSE,
  k = 2,
  buffer_m = 3000,
  max_cells = NULL,
  seed = 1,
  invert = FALSE
)
```

## Arguments

- friction:

  movement-cost `SpatRaster` (e.g.
  [`build_resistance`](https://sagesteppe.github.io/lsed/reference/build_resistance.md)
  or
  [`tobler_friction`](https://sagesteppe.github.io/lsed/reference/tobler_friction.md));
  values must be positive.

- sources:

  source features (sf/`SpatVector`): occupied populations for **Dr**,
  the road/trail network for **A**.

- template:

  output grid (defaults to `friction`).

- tile:

  split into buffered regions around source clusters (default `FALSE`).

- k, buffer_m, max_cells, seed:

  tiling controls, passed to
  [`cluster_region_extents`](https://sagesteppe.github.io/lsed/reference/cluster_region_extents.md)
  (`res_m` is taken from `friction`).

- invert:

  if `TRUE`, return \\1 - \tilde d\\ (near/accessible = high).

## Value

a single-layer `SpatRaster` on \\\[0, 1\]\\.

# Complementarity of patches: can a day's work be assembled nearby? (C)

An isolation penalty, scaled by **area** rather than count so a knot of
fragments does not out-rank a real patch. For each patch, walk outward
over the network (cheapest travel first) accumulating neighbouring patch
*acreage* until a `target_area` day's worth is gathered; the travel cost
that bundle required is the isolation measure. A dense cluster assembles
the target cheaply; a lone fragment must range far (or cannot gather it
at all). The score is flipped so well-connected patches are high and
isolated ones are penalised - no day-length assumption, just the area
target.

## Usage

``` r
complementarity(
  net,
  patch_nodes,
  areas,
  target_area = 50,
  cap_q = 0.95,
  cores = 1,
  invert = TRUE
)
```

## Arguments

- net:

  the `net` element from
  [`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md)
  (its `graph` holds the patch nodes).

- patch_nodes:

  the `patch_nodes` from
  [`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md),
  aligned to `areas`.

- areas:

  numeric patch areas (acres), one per `patch_nodes` in order.

- target_area:

  a day's worth of patch area to assemble, in acres (default `50`;
  loose - the saturation scale, not a hard quota).

- cap_q:

  upper quantile (on \\(0, 1\]\\) at which the raw assembly cost is
  clamped before rescaling (default `0.95`). The isolation cost has a
  long right tail - a lone fragment can range far, and unreachable
  patches are `Inf` - so a single outlier otherwise stretches the
  min-max rescale and flattens the gradient among the patches that
  actually differ. Costs above the `cap_q` quantile of the *finite*
  costs (and every `Inf`) are set to that quantile: all such patches
  count as equally, maximally isolated. The cap is applied to
  `assemble_hr` itself, so it also carries through when the raw hours
  are rescaled downstream (e.g. by
  [`rank_index`](https://sagesteppe.github.io/lsed/reference/rank_index.md)
  in
  [`rank_calculate`](https://sagesteppe.github.io/lsed/reference/rank_calculate.md)).
  `NULL` disables the cap (then `Inf` falls back to the worst finite
  cost, as before).

- cores:

  fork workers for the per-patch distance loop (default `1`); the loop
  is the cost, so `cores` gives a near-linear speed-up (Unix only; falls
  back to serial on Windows).

- invert:

  if `TRUE` (default), return the flipped score \\1 - \tilde c\\
  (well-connected = high), the index form; raw assembly cost is kept in
  `assemble_hr`.

## Value

a data.frame with `patch_node`, `assemble_hr` (travel hours to gather
`target_area`, clamped at the `cap_q` quantile; patches that never total
it take that capped worst value) and `C` on \\\[0, 1\]\\, in
`patch_nodes` order.

## Details

Run on the augmented graph returned by
[`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md)
(patches are already nodes there). Distances are computed one source at
a time, so memory stays O(n) for large patch sets.

## See also

[`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md)

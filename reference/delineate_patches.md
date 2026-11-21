# Delineate patches by marker-controlled watershed

Binarise `pr` at `sens_spec`, then split the suitable network with a
marker-controlled watershed on the *inverted* surface (high-probability
cores become pits; necks shallower than `delta` are merged by depression
filling, surviving pits seed the watershed). Suitable cells that drain
off-mask (small patches with no interior pit) keep an identity through a
rook's-case (4-connected) component fallback, so none are dropped.
Patches at or below `min_area` m^2 are removed as un-surveyable slivers.
Watershed intermediates are written to `rdir` so a partial re-run can
reuse finished steps.

## Usage

``` r
delineate_patches(pr, sens_spec, delta, min_area, rdir)
```

## Arguments

- pr:

  A terra `SpatRaster` of predicted probability (one layer).

- sens_spec:

  Suitable-habitat threshold in probability units; cells `>= sens_spec`
  are suitable.

- delta:

  Prominence (minimum neck depth, probability units) below which two
  cores are merged rather than split. Passed to
  `wbt_fill_depressions(max_depth=)`.

- min_area:

  Patches with total area at or below this (m^2) are dropped.

- rdir:

  Directory for the watershed intermediate rasters
  (dem/fill/sink/pntr/seg).

## Value

A `SpatRaster` of integer patch ids (`NA` off-patch), aligned to `pr`.

## See also

[`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md)

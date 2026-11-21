# Reconcile watershed labels with off-mask suitable cells

Post-watershed assembly: take the raw watershed segmentation `seg` and
the suitability `mask`, drop the watershed's zero/negative background,
and give an identity to suitable cells the watershed left unlabelled
(those that drained off-mask, i.e. small patches with no interior pit)
via a rook's-case (4-connected) component pass. Those fallback component
ids are shifted above the maximum watershed label so the two id spaces
never collide, then layered under the watershed labels with
[`terra::cover`](https://rspatial.github.io/terra/reference/cover.html)
and clipped back to the mask.

## Usage

``` r
merge_offmask(seg, mask)
```

## Arguments

- seg:

  A `SpatRaster` of raw watershed segment labels (0/negative =
  background).

- mask:

  A logical `SpatRaster`: `TRUE` on suitable cells.

## Value

A `SpatRaster` of integer patch ids (`NA` off-mask), before the sliver
filter.

## See also

[`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md),
[`drop_slivers`](https://sagesteppe.github.io/lsed/reference/drop_slivers.md)

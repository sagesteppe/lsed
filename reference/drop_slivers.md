# Drop patches below a minimum area

Remove patches whose total area (cell count times cell area) is at or
below `min_area` m^2, as un-surveyable slivers. The surviving patch ids
keep their original values (ids are *not* renumbered), so an id-space
built upstream stays valid.

## Usage

``` r
drop_slivers(patch_id, min_area)
```

## Arguments

- patch_id:

  A `SpatRaster` of integer patch ids (`NA` off-patch).

- min_area:

  Patches with total area at or below this (m^2) are dropped.

## Value

`patch_id` with the sliver patches set to `NA`.

## See also

[`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md)

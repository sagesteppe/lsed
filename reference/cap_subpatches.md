# Subdivide oversized patches by a compact geometric cap (k-means lever)

The simpler alternative to
[`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md):
ignore suitability and split each patch purely on geometry. A patch at
or below the cap passes through as one unit; a larger one is cut into
`ceil(area / cap)` compact k-means pieces, each at or below
`max_area_ac` acres
([`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)). Units
are numbered sequentially across patches. Compact partitions, not
watersheds – a concave patch can yield a unit in disjoint pieces.

## Usage

``` r
cap_subpatches(cells, memb, nc, cell_area, max_area_ac, seed = 1, cores = 1)
```

## Arguments

- cells:

  Integer vector of the global cell indices of all suitable cells.

- memb:

  Integer vector (same length as `cells`) of parent patch id per cell.

- nc:

  Number of columns in the parent raster (for col/row recovery in
  [`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)).

- cell_area:

  Area of one cell (m^2).

- max_area_ac:

  Maximum unit size (acres).

- seed:

  Base random seed; each patch is seeded `seed + patch id` so its split
  is reproducible and independent of patch order / core count.

- cores:

  Integer worker count for
  [`papply`](https://sagesteppe.github.io/lsed/reference/papply.md) (`1`
  = serial).

## Value

Integer vector (same length as `cells`) of subpatch unit ids.

## See also

[`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md),
[`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)

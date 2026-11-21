# Subdivide oversized patches by suitability banding

For each patch larger than `trig_ac` acres: cut cells into fixed
suitability *bands* on the raw surface, find same-band connected pieces,
snap sub-threshold pieces into their highest-band contiguous neighbour
([`snap_pieces`](https://sagesteppe.github.io/lsed/reference/snap_pieces.md)),
then geometrically cap any surviving unit above `cap_cells`
([`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)). Patches
at or below `trig_ac` pass through as a single unit. Units are numbered
sequentially across all patches.

## Usage

``` r
band_subpatches(
  cells,
  memb,
  pval,
  nc,
  nr,
  cell_area,
  band_brks,
  band_minac,
  trig_ac,
  cap_cells,
  seed = 1,
  cores = 1
)
```

## Arguments

- cells:

  Integer vector of the global cell indices of all suitable cells (i.e.
  `which(!is.na(values(patch_id)))`).

- memb:

  Integer vector (same length as `cells`) of the parent patch id per
  suitable cell.

- pval:

  Numeric vector of probability values at the suitable cells, **aligned
  to `cells`** (i.e. `pr[cells][, 1]`), not the whole surface. Reading
  only these cells avoids materialising the full raster.

- nc, nr:

  Columns and rows of the parent raster.

- cell_area:

  Area of one cell (m^2).

- band_brks:

  Numeric band edges on the raw surface (length = n bands + 1), passed
  to `cut(right = FALSE)`.

- band_minac:

  Numeric per-band minimum size (acres) for
  [`snap_pieces`](https://sagesteppe.github.io/lsed/reference/snap_pieces.md).

- trig_ac:

  Only patches larger than this (acres) are banded.

- cap_cells:

  Maximum final unit size in cells (geometric cap).

- seed:

  Base random seed. Each patch is seeded `seed + patch id`, so its split
  is reproducible and **independent of patch order / core count**.

- cores:

  Integer worker count for
  [`papply`](https://sagesteppe.github.io/lsed/reference/papply.md) (`1`
  = serial).

## Value

Integer vector (same length as `cells`) of subpatch unit ids.

## See also

[`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md),
[`snap_pieces`](https://sagesteppe.github.io/lsed/reference/snap_pieces.md),
[`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)

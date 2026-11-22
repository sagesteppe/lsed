# Build an isotropic resistance (friction) surface

Lifted from safeHavens `buildResistanceSurface()` (terra-only). Sums
weighted, optional layers — water features, terrain ruggedness, habitat
and any extras — into a per-cell cost of movement, clamped to a floor of
1 and stored as integer. Feed the result to
[`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md)
for **Dr**.

## Usage

``` r
build_resistance(
  base_raster,
  resistance_surface = NULL,
  oceans = NULL,
  lakes = NULL,
  rivers = NULL,
  tri = NULL,
  habitat = NULL,
  w_ocean = 100,
  w_lakes = 50,
  w_rivers = 20,
  w_tri = 1,
  w_habitat = 1,
  addtl_r = NULL,
  addtl_w = NULL
)
```

## Arguments

- base_raster:

  `SpatRaster` giving template geometry/resolution.

- resistance_surface:

  optional precomputed resistance; if given, the builder arguments are
  ignored (geometry must match `base_raster`).

- oceans, lakes, rivers:

  binary (0/1) `SpatRaster`s of water features.

- tri:

  continuous terrain-ruggedness `SpatRaster` (z-scored internally).

- habitat:

  continuous `SpatRaster` whose *high* values raise cost; for a
  dispersal surface pass inverted suitability (e.g. `1 - suitability`)
  so movement through good habitat is cheap.

- w_ocean, w_lakes, w_rivers, w_tri, w_habitat:

  weights applied to each layer.

- addtl_r:

  extra `SpatRaster` stack; `addtl_w` their weights (same length as
  `terra::nlyr(addtl_r)`).

- addtl_w:

  see `addtl_r`.

## Value

an integer `SpatRaster` of movement cost (minimum 1).

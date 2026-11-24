# Dispersal and accessibility terms (Dg, Dr, A) by isotropic cost distance

The `RankIndex` distance terms, all on one terra-native, isotropic
engine (no gdistance/raster): a friction surface plus
[`costDist`](https://rspatial.github.io/terra/reference/costDist.html)
from a set of sources, tiled so large domains stay in memory.

## Details

- **Dg** - geographic distance from a known population:
  [`geo_distance`](https://sagesteppe.github.io/lsed/reference/geo_distance.md)
  (straight-line
  [`distance`](https://rspatial.github.io/terra/reference/distance.html)
  to the nearest source).

- **Dr** - resistance distance:
  [`build_resistance`](https://sagesteppe.github.io/lsed/reference/build_resistance.md)
  friction -\>
  [`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md)
  from occupied populations.

- **A** - accessibility:
  [`tobler_friction`](https://sagesteppe.github.io/lsed/reference/tobler_friction.md)
  (walking cost) -\>
  [`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md)
  from the road/trail network.

All three return a surface rescaled to \\\[0, 1\]\\; because the index
rewards *short* distance / *easy* access, pass `invert = TRUE` for the
\\1 - \tilde d\\ form the index consumes.

[`build_resistance()`](https://sagesteppe.github.io/lsed/reference/build_resistance.md)
is lifted from safeHavens (`buildResistanceSurface`); the tiling
([`cluster_region_extents`](https://sagesteppe.github.io/lsed/reference/cluster_region_extents.md),
mosaic-by-min) is lifted from the `Ecoloradense` cost-distance script.
Both are terra/sf only - the lift adds no dependency beyond terra, sf.

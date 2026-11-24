# Accessibility of patches over the network (A)

Finds the travel time from the **origin** (field office / trailhead) to
each patch: drive the roads, walk the trails, then an off-trail Tobler
hop to the centroid. Each patch is joined to its `k` nearest
**origin-reachable** nodes and takes the cheapest total route, so a
patch beside an isolated trail fragment bushwhacks to the usable network
(a finite cost) instead of coming back `NA`, and can enter via a
connected trail it passes rather than a dead-end stub. Returns the
patches with a rescaled score *and* the augmented graph (with patches as
nodes), so
[`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md)
runs on the same structure.

## Usage

``` r
accessibility(
  lines,
  patches,
  dem = NULL,
  origins = NULL,
  k = 3,
  road_speed = 30,
  trail_speed = 4,
  snap = 1,
  connect = 50,
  speeds = osm_speeds,
  offtrail_speed = 5,
  offtrail_penalty = 0.5,
  invert = TRUE
)
```

## Arguments

- lines:

  road/trail sf lines (see
  [`build_network`](https://sagesteppe.github.io/lsed/reference/build_network.md)).

- patches:

  sf points or polygons; polygons are reduced to centroids.

- dem:

  optional elevation `SpatRaster` (same CRS) for the Tobler hop slope;
  without it the hop uses `offtrail_speed` on the flat.

- origins:

  trip start as sf point(s) - typically the **field office**, snapped
  free to the nearest road, after which road driving accrues time (often
  the dominant cost). `NULL` (default) treats every road node as a
  zero-cost origin ("distance from the road network", ignoring the
  drive).

- k:

  nearest origin-reachable nodes each patch may enter through (default
  `3`); the route uses whichever minimises drive/walk + hop.

- road_speed, trail_speed, snap, connect, speeds:

  passed to
  [`build_network`](https://sagesteppe.github.io/lsed/reference/build_network.md)
  (`speeds` is the per-`highway` km/h lookup, default
  [`osm_speeds`](https://sagesteppe.github.io/lsed/reference/osm_speeds.md);
  `connect` bridges trailhead gaps).

- offtrail_speed:

  unpenalised flat-ground off-trail speed in km/h when `dem` is absent
  (default `5`, ~Tobler on the level).

- offtrail_penalty:

  multiplier on the off-trail hop speed (default `0.5`): cross-country
  through brush/talus is slower than the slope-only Tobler ideal, so
  this keeps trails faster than bushwhacking. `1` removes the penalty.

- invert:

  if `TRUE` (default), the returned `A` is \\1 - \tilde t\\ (accessible
  = high), the index form; raw hours are kept in `access_hr`.

## Value

a list: `patches` (input patches + `access_hr` and `A`), `net` (the
augmented `build_network` list), and `patch_nodes` (the patch vertex
names) for reuse by
[`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md).

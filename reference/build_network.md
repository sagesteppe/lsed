# Build a travel-time graph from road/trail linestrings

Build a travel-time graph from road/trail linestrings

## Usage

``` r
build_network(
  lines,
  road_speed = 30,
  trail_speed = 4,
  snap = 1,
  connect = 50,
  speeds = osm_speeds
)
```

## Arguments

- lines:

  sf LINESTRINGs in a projected CRS (metres), with a `class` column
  ("road"/"trail"); `osm_access` output fits directly.

- road_speed, trail_speed:

  fallback class speeds in km/h (defaults 30, 4) for a `highway` tag not
  listed in `speeds`.

- snap:

  tight grid (metres) that segment endpoints snap to when forming nodes
  (default 1) — within-class noding, so parallel switchbacks/lanes are
  not fused.

- connect:

  liberal tolerance (metres, default 50) for bridging a **stub end** of
  one class to the nearest node of the *other* class — i.e. closing
  trailhead gaps where a trail dead-ends near a road (or a road near a
  trail) without a shared OSM node. Set `0` to disable. Only degree-1
  ends are bridged, so it never fuses same-class features.

- speeds:

  named per-`highway` speed lookup in km/h (default
  [`osm_speeds`](https://sagesteppe.github.io/lsed/reference/osm_speeds.md));
  each contracted edge is single-`highway`, so one speed applies. Edge
  weight is `length / speed` — change `speeds` and rebuild (cheap) to
  re-time without re-pulling or re-contracting.

## Value

a list: `graph` (an undirected igraph with edge `weight` in hours and
`class` — road/trail/connect, vertex coords `x`/`y`) and `nodes`
(data.frame of node `name`, `x`, `y`).

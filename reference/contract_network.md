# Contract an OSM network to junction-to-junction edges

Collapses the raw OSM lines (every way vertex is a potential node, ~30x
more than needed) into one edge per junction-to-junction run, so the
downstream graph is tiny and every distance query is fast. Uses
sfnetworks: subdivide at interior junctions, then `to_spatial_smooth`
drops degree-2 nodes — but only within a single `require_equal` class,
so motorway/primary/secondary/path boundaries survive (and can carry
different speeds later). Distance-preserving: a smoothed edge's length
is the sum of the run it replaces.

## Usage

``` r
contract_network(lines, require_equal = "highway")
```

## Arguments

- lines:

  road/trail sf lines with a `highway` (and `class`) column, e.g. from
  [`osm_access`](https://sagesteppe.github.io/lsed/reference/osm_access.md).

- require_equal:

  edge attribute that must match for two edges to be smoothed together
  (default `"highway"` — never merge across road classes).

## Value

the contracted sf lines (one feature per junction-to-junction run),
`highway`/`class` preserved — write this to disk and feed it to
[`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md).

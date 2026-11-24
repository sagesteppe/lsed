# Fetch an OSM network scoped to patch clusters, connected to an origin

Pulls dense roads+trails only within boxes around each patch cluster
([`cluster_patches`](https://sagesteppe.github.io/lsed/reference/cluster_patches.md)),
plus a **roads-only** connective layer over the envelope of the origin
and all clusters. The field office then drives in on one connected
network to every cluster, without fetching the empty country between
them (the hard part of a scattered domain). Reuses
[`osm_access`](https://sagesteppe.github.io/lsed/reference/osm_access.md)
for every sub-pull, so caching, throttling and back-off all apply.

## Usage

``` r
osm_network_for(
  patches,
  origin,
  crs = NULL,
  eps_km = 5,
  buffer_m = 1500,
  roads = c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified",
    "residential", "service", "living_street", "road", "track"),
  trails = c("path", "footway", "bridleway", "cycleway", "steps"),
  connect_roads = c("motorway", "trunk", "primary", "secondary", "tertiary"),
  path = NULL,
  cache_dir = NULL,
  tiles_connect = NULL,
  local_tile_km = 20,
  contract = TRUE,
  ...
)
```

## Arguments

- patches:

  sf points/polygons to scope the pull to.

- origin:

  the trip origin (field office): an sf point, or a numeric
  `c(lon, lat)` in EPSG:4326.

- crs:

  planar CRS (metres) to work in; defaults to the patches' CRS.

- eps_km:

  cluster join distance (km, default `5`; see
  [`cluster_patches`](https://sagesteppe.github.io/lsed/reference/cluster_patches.md)).

- buffer_m:

  buffer (m) added around each cluster's bounding box (default `1500`).

- roads, trails:

  OSM `highway` classes pulled densely *within* cluster boxes (`trails`
  only there).

- connect_roads:

  the (major) road classes for the *connective* envelope layer that
  links the origin to the clusters — default the through-routes
  `motorway/trunk/primary/secondary/tertiary`. Residential/service/track
  are left out here: they are local bloat and already come from the
  cluster pulls.

- path:

  GeoPackage for the merged network (`NULL` -\> cwd).

- cache_dir:

  folder for the per-pull checkpoints (`NULL` -\> beside `path`);
  existing pulls are reused, so the whole fetch is resumable.

- tiles_connect:

  tiles for the connective roads pull (`NULL` -\> ~1 per 30 km of
  envelope width).

- local_tile_km:

  target tile width (km) for each cluster's dense pull, so a big habitat
  block is not one enormous Overpass query (default `20`).

- contract:

  simplify the merged network to junction-to-junction edges before
  writing (default `TRUE`;
  [`contract_network`](https://sagesteppe.github.io/lsed/reference/contract_network.md))
  — the on-disk file is then the contracted version, ~30x fewer graph
  nodes.

- ...:

  passed to
  [`osm_access`](https://sagesteppe.github.io/lsed/reference/osm_access.md)
  (e.g. `endpoint`, `contact`, `pause`).

## Value

a list: `network` (merged sf lines, deduped), `origin` (sf point in
`crs`) and `clusters` (centroids with `cluster` ids); attribute `path`
is where the network was written. Feed `network` + `origin` to
[`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md).

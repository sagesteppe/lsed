# Acquire every external input for the patch ranking (download module)

The data-acquisition half of the patch ranking, kept separate from the
calculation so the slow, network-bound, API-dependent work runs once and
its outputs can be re-used. It overlaps the two big pulls: GBIF's bulk
download is **requested** first (and prepared server-side while we
wait), the OSM road/trail network is fetched in that window, and only
then do we come **back** to collect the finished GBIF archive — so the
GBIF prep time is spent fetching OSM, not idling.

## Usage

``` r
rank_download(
  patches,
  origin,
  crs = NULL,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  gbif_path = "data/gbif_records.gpkg",
  osm_path = "data/osm_network.gpkg",
  eps_km = 5,
  buffer_m = 1500,
  ...
)
```

## Arguments

- patches:

  sf patches (points/polygons) that scope both pulls.

- origin:

  trip origin for accessibility — sf point or `c(lon, lat)` (see
  [`osm_network_for`](https://sagesteppe.github.io/lsed/reference/osm_network_for.md)).

- crs:

  planar working CRS (metres); defaults to the patches' CRS.

- taxon_key, basis, year_from, coord_uncertainty_max:

  GBIF filters
  ([`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md)).

- gbif_path, osm_path:

  output GeoPackages for the records and the network.

- eps_km, buffer_m:

  cluster-scoping for the OSM pull
  ([`osm_network_for`](https://sagesteppe.github.io/lsed/reference/osm_network_for.md)).

- ...:

  further arguments to
  [`osm_network_for`](https://sagesteppe.github.io/lsed/reference/osm_network_for.md)
  (e.g. `connect_roads`, `endpoint`, `contact`, `pause`).

## Value

a list: `records` (GBIF sf), `network` (OSM sf), `origin` (sf point),
`clusters`, and `doi` — everything the calculation step needs.

## Details


      gbif_request()  --->  (GBIF prepares server-side)  ---.
                                                             |
      osm_network_for()  (runs during the wait)             |
                                                             v
                                                      gbif_retrieve()

Needs a GBIF account (see
[`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md)).
Everything is written to disk (GeoPackages), so a later `rank`
calculation reads files, not live APIs.

## See also

[`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md),
[`osm_network_for`](https://sagesteppe.github.io/lsed/reference/osm_network_for.md),
[`rank_index`](https://sagesteppe.github.io/lsed/reference/rank_index.md)

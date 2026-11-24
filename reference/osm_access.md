# Fetch the OSM access network (roads + trails) for a domain

A convenience fetcher for the **A** (accessibility) and **C**
(complementarity) terms: pulls the OpenStreetMap highway network inside
a bounding box from an Overpass endpoint and returns it as sf lines,
ready to pass as `sources` to
[`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md).
OpenTrailMap and similar viewers are just renderers of this same OSM
data.

## Usage

``` r
osm_access(
  bbox,
  crs = NULL,
  roads = c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified",
    "residential", "service", "living_street", "road"),
  trails = c("path", "footway", "track", "bridleway", "cycleway", "steps"),
  path = NULL,
  cache_dir = NULL,
  overwrite = FALSE,
  endpoint = "https://overpass-api.de/api/interpreter",
  contact = NULL,
  tiles = 1L,
  exclude = NULL,
  pause = 1,
  max_tries = 4L,
  timeout = 50
)
```

## Arguments

- bbox:

  the domain: an sf/terra object (its extent is used), or a numeric
  `c(xmin, ymin, xmax, ymax)` in lon/lat (EPSG:4326).

- crs:

  output CRS (anything
  [`sf::st_crs`](https://r-spatial.github.io/sf/reference/st_crs.html)
  accepts). Defaults to the input object's CRS, else lon/lat.

- roads, trails:

  OSM `highway` values to treat as each class; the returned lines carry
  a `class` column ("road"/"trail"). Set either to `character(0)` to
  skip it.

- path:

  file to write the merged network to (GeoPackage). `NULL` (default)
  writes `osm_access.gpkg` in the working directory.

- cache_dir:

  directory for per-tile checkpoints (one `.rds` per tile). `NULL`
  (default) uses a folder named after `path` beside it. Existing tiles
  here are reused unless `overwrite = TRUE`; delete it to force a fresh
  pull.

- overwrite:

  refetch and overwrite cached tiles (default `FALSE`).

- endpoint:

  Overpass API URL (default the public instance — override for your
  own).

- contact:

  optional contact string appended to the User-Agent (opt-in; e.g. a
  project URL or email you choose to share). `NULL` sends none.

- tiles:

  split the bbox into a `tiles` x `tiles` grid of requests (default
  `1`).

- exclude:

  optional geometry (sf/sfc, any CRS) of ground already covered
  elsewhere; any tile falling *entirely* within it is skipped — never
  fetched — so overlapping pulls don't re-query the API. Its benefit
  grows as tiles shrink toward the excluded regions' size.

- pause:

  minimum seconds between requests (default `1`); also the base of the
  retry backoff.

- max_tries:

  attempts per tile before giving up (default `4`).

- timeout:

  Overpass server-side `[timeout:]` seconds (default `50`).

## Value

an sf object of `LINESTRING`s with `osm_id`, `highway` and `class`
columns, in `crs`; attributes `timestamp` (OSM base time) and `path`
(where it was written). Pass straight to
[`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md)
as `sources`.

## Details

**Be a good citizen.** Public Overpass instances are a shared,
volunteer-run resource with a tight usage policy. This helper makes only
modest promises and tries to behave:

- **Batches** a large domain into `tiles`^2 smaller queries rather than
  one giant one.

- **Checkpoints** every tile to `cache_dir` the moment it returns, and
  on a re-run **skips** any tile already cached — so an interrupted or
  retried pull resumes instead of re-hammering the API.

- **Breathes** between calls (`req_throttle`) and **backs off**
  exponentially on transient failures / rate limits (429/502/503/504,
  honouring any `Retry-After`).

- Sends a plain **User-Agent** and never your identity. If you have a
  contact address you are willing to share per OSM etiquette, pass it in
  `contact` — it is *opt-in*, never read from your session.

For anything heavy, run your **own Overpass instance** (or a provider
you have an account with) and point `endpoint` at it — do not hammer the
public API.

Data is \\\copyright\\ OpenStreetMap contributors, **ODbL**: attribute
it, and snapshot the result (the `timestamp` attribute records the OSM
base time) so analyses stay reproducible as OSM changes.

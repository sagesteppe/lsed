# Score patches from the downloaded inputs (calculate module)

The calculation half of the patch ranking: given the data acquired by
[`rank_download`](https://sagesteppe.github.io/lsed/reference/rank_download.md)
plus the on-disk surfaces, it computes every `RankIndex` term, samples
the raster terms at the patch centroids, and combines them with
[`rank_index`](https://sagesteppe.github.io/lsed/reference/rank_index.md).
No network calls — it reads the files the download module wrote, so it
is fast to re-run while tuning weights.

## Usage

``` r
rank_calculate(
  patches,
  occ,
  suitability,
  records = NULL,
  network = NULL,
  origin = NULL,
  dem = NULL,
  resistance = NULL,
  agg = 10,
  area_col = "acres",
  prob_col = "prob_mean",
  sigma = 100,
  target_area = 50,
  cap_q = 0.95,
  k = 3,
  w_habitat = 5,
  cores = 1,
  speeds = osm_speeds,
  cluster_eps_km = NULL,
  cluster_buffer_m = 1500,
  weights = NULL
)
```

## Arguments

- patches:

  sf units to score (polygons or points); must carry `area_col` for
  **C**.

- occ:

  known-population points (sf/`SpatVector`) — the sources for **Dg** and
  **Dr**.

- suitability:

  habitat-suitability `SpatRaster` (or path): the template for the
  raster terms and, inverted, the dispersal resistance.

- records:

  GBIF sf with `speciesKey` (and `basisOfRecord`) for **S**; `NULL`
  skips it.

- network, origin:

  OSM road/trail sf and the trip origin for **A**/ **C**; `NULL` skips
  them.

- dem:

  optional elevation `SpatRaster` for the accessibility off-trail hop.

- resistance:

  optional precomputed friction `SpatRaster` for **Dr**; `NULL` builds
  one from inverted suitability
  ([`build_resistance`](https://sagesteppe.github.io/lsed/reference/build_resistance.md)).

- agg:

  integer factor to coarsen `suitability` by before the raster terms
  (default `10`); the ranking is sampled at centroids, so fine
  resolution is wasted here.

- area_col:

  patch-area column (acres) used by **C** (default `"acres"`).

- prob_col:

  patch column holding the model suitability to enter as a term `P`
  (default `"prob_mean"`); a more-suitable patch is likelier real
  habitat. `NULL` omits it.

- sigma, target_area, k, w_habitat, speeds:

  term parameters passed through to
  [`survey_surface`](https://sagesteppe.github.io/lsed/reference/survey_surface.md)
  /
  [`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md)
  /
  [`accessibility`](https://sagesteppe.github.io/lsed/reference/accessibility.md)
  /
  [`build_resistance`](https://sagesteppe.github.io/lsed/reference/build_resistance.md).

- cap_q:

  upper quantile at which **C**'s raw assembly cost is clamped before
  the global rescale (default `0.95`; passed to
  [`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md)).
  `NULL` disables the cap. See
  [`complementarity`](https://sagesteppe.github.io/lsed/reference/complementarity.md)
  for why the tail is clamped.

- cluster_eps_km:

  if set, compute **A**/**C** per spatial cluster (bbox) rather than on
  one domain-wide graph: patches within this distance (km) share a
  cluster
  ([`cluster_patches`](https://sagesteppe.github.io/lsed/reference/cluster_patches.md)),
  and each cluster is routed on its own small graph — all roads (for the
  drive-in) plus only that cluster's trails. `NULL` (default) uses a
  single graph. The per-cluster split is a big win when patches are
  scattered; raw travel times are rescaled once, globally, so clusters
  stay comparable. Cross-cluster co-visitation is negligible at this
  separation.

- cluster_buffer_m:

  buffer (m) around each cluster's bbox when selecting its local trails
  (default `1500`).

- weights:

  per-term multipliers for
  [`rank_index`](https://sagesteppe.github.io/lsed/reference/rank_index.md)
  (default equal).

## Value

`patches` with the rescaled term columns, `index` and `rank` appended
(an sf).

## Details

Terms are computed only when their inputs are supplied, so the ranking
degrades gracefully: omit `records` to drop **S**, omit
`network`/`origin` to drop **A**/**C**. **Dg**/**Dr** need only `occ`
and `suitability`.

## See also

[`rank_download`](https://sagesteppe.github.io/lsed/reference/rank_download.md),
[`rank_index`](https://sagesteppe.github.io/lsed/reference/rank_index.md)

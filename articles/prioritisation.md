# Prioritising sites for survey (RankIndex)

`lsed` turns a species-distribution prediction into an operational
survey plan. Given candidate patches (mapped survey units, or any
polygons/points) it scores each one with a **RankIndex**, a weighted
mean of rescaled terms, so a land manager can more quickly prioritise
survey work.

\\\mathrm{Rank}(x) = D_g + D_r + S + A + C \\(+\\P)\\

| Term | Meaning | Function |
|----|----|----|
| **Dg** | geographic distance to a known population | [`geo_distance()`](https://sagesteppe.github.io/lsed/reference/geo_distance.md) |
| **Dr** | resistance (cost) distance over a friction surface | [`build_resistance()`](https://sagesteppe.github.io/lsed/reference/build_resistance.md), [`cost_distance()`](https://sagesteppe.github.io/lsed/reference/cost_distance.md) |
| **S** | survey intensity (effort already spent nearby) | [`survey_surface()`](https://sagesteppe.github.io/lsed/reference/survey_surface.md) |
| **A** | accessibility: travel time from the field office | [`accessibility()`](https://sagesteppe.github.io/lsed/reference/accessibility.md) |
| **C** | complementarity: can a day’s work be assembled nearby | [`complementarity()`](https://sagesteppe.github.io/lsed/reference/complementarity.md) |
| **P** | the patch’s own predicted suitability | (a column you supply) |

Every term is rescaled to `[0, 1]` and oriented so **high = higher
priority**, then combined by
[`rank_index()`](https://sagesteppe.github.io/lsed/reference/rank_index.md).
You can compute the terms yourself, or let
[`rank_calculate()`](https://sagesteppe.github.io/lsed/reference/rank_calculate.md)
assemble all of them from a handful of inputs.

``` r

library(lsed)
library(terra) ## raster surfaces
library(sf)    ## vector geometries
set.seed(1)    ## reproducibility
```

## A toy landscape

We fabricate the inputs a real run would read from disk: a predicted
suitability surface, a few candidate patches (with an area column for
**C** and a suitability column for **P**), and the known populations
that anchor **Dg** / **Dr**.

``` r

crs <- "EPSG:3857"
mk <- function(x, y, s = 60) {
  sf::st_polygon(list(rbind(c(x, y), c(x + s, y), c(x + s, y + s),
                            c(x, y + s), c(x, y))))
}

suitability <- terra::rast(terra::ext(0, 1000, 0, 1000), resolution = 50, crs = crs)
terra::values(suitability) <- runif(terra::ncell(suitability))

patches <- sf::st_sf(
  acres     = c(10, 20, 30, 40),
  prob_mean = c(0.2, 0.4, 0.6, 0.8),
  geometry  = sf::st_sfc(mk(100, 100), mk(300, 300), mk(600, 600), mk(800, 200),
                         crs = crs))

occ <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(150, 150)),
                                       sf::st_point(c(850, 850)), crs = crs))
```

Models predict on pixels. Crews run on patches. Using the `patches`
function we define reasonably sized patches for survey work. It has
multiple tunable parameters; with delta and max area giving the largest
effects. These can be swapped for other units you utilise for decisions.

## The one-call route: `rank_calculate()`

[`rank_calculate()`](https://sagesteppe.github.io/lsed/reference/rank_calculate.md)
computes every term it has the inputs for and combines them. Supply only
`patches`, `occ` and `suitability` and you get **Dg**, **Dr** and **P**;
add a road/trail `network` and an `origin` for **A** / **C**; add
`records` for **S**.

``` r

# a minimal road + trail network and a field-office origin
network <- sf::st_sf(
  class = c("road", "trail"), highway = c("primary", "path"),
  geometry = sf::st_sfc(
    sf::st_linestring(rbind(c(0, 0), c(1000, 0))),
    sf::st_linestring(rbind(c(0, 0), c(900, 900))), crs = crs))
origin <- sf::st_sf(geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = crs))
```

``` r
ranked <- rank_calculate(
  patches, occ = occ, suitability = suitability,
  network = network, origin = origin,
  agg = 1, area_col = "acres", prob_col = "prob_mean")

sf::st_drop_geometry(ranked)
  acres prob_mean        Dg        Dr         A         C         P     index
1    10       0.2 1.0000000 1.0000000 1.0000000 1.0000000 0.0000000 0.8000000
2    20       0.4 0.6405422 0.6375938 0.6000000 0.4789095 0.3333333 0.5380758
3    30       0.6 0.5207229 0.5931203 0.0000000 0.0000000 0.6666667 0.3561020
4    40       0.8 0.0000000 0.0000000 0.6724953 1.0000000 1.0000000 0.5344991
  rank
1    1
2    2
3    4
4    3
```

## The terms one at a time

When you want to inspect or re-weight a single term, build it directly.
Each returns a surface (sample it at the patch centroids) or a per-patch
vector.

``` r

# Dg: geographic distance (near = high)
dg <- geo_distance(occ, suitability, invert = TRUE)

# Dr: resistance distance over an inverted-suitability friction
fric <- build_resistance(suitability, habitat = 1 - suitability)
dr   <- cost_distance(fric, occ, template = suitability, invert = TRUE)

# A / C: travel on the network, patches become graph nodes
acc  <- accessibility(network, patches, origins = origin)
comp <- complementarity(acc$net, acc$patch_nodes, areas = patches$acres)
```

## Combining and re-weighting

[`rank_index()`](https://sagesteppe.github.io/lsed/reference/rank_index.md)
takes named per-patch term vectors (equal length, same order) and
returns the rescaled columns plus `index` and `rank`. Pass `weights` to
emphasise a term.

``` r
rank_index(
  Dg = c(0.1, 0.4, 0.8, 0.5),
  A  = c(0.9, 0.6, 0.2, 0.7),
  weights = c(A = 2)        # accessibility counts double
)
         Dg         A     index rank
1 0.0000000 1.0000000 0.6666667    1
2 0.4285714 0.5714286 0.5238095    3
3 1.0000000 0.0000000 0.3333333    4
4 0.5714286 0.7142857 0.6666667    1
```

## Acquiring the inputs (GBIF + OSM)

In practice the records and road+trail network come from external APIs.
[`rank_download()`](https://sagesteppe.github.io/lsed/reference/rank_download.md)
requests the GBIF bulk download, fetches the OSM network while GBIF
prepares it, then collects the finished GBIF archive. These need a GBIF
account and a network connection, so they are shown but not run here.

``` r

inputs <- rank_download(
  patches, origin = c(-105.3, 40.0),   # lon/lat field office
  taxon_key = 7707728,                 # Tracheophyta
  gbif_path = "data/gbif_records.gpkg",
  osm_path  = "data/osm_network.gpkg")

ranked <- rank_calculate(
  patches, occ = occ, suitability = suitability,
  records = inputs$records, network = inputs$network, origin = inputs$origin)
```

Calculating the survey intensity term requires a gbif account, and is
accessed via rgbif. See
[here](https://docs.ropensci.org/rgbif/articles/rgbif.html) for details
on setting up a gbif account (it’s about a five minute process).

Our OSM access function is hand rolled in this package. We endeavoured
to make it as light on their server as possible. Please carefully
consider your landscape, and needs before download.

By default we persist all OSM data to disk. Please do not delete it
(reduce, reuse, recyle).

## See also

- [`vignette("lsed")`](https://sagesteppe.github.io/lsed/articles/lsed.md)
  for the prevalence-corrected evaluation (DCA) side of the package.
- The function reference, grouped by RankIndex term, at
  <https://sagesteppe.github.io/lsed/reference/>.

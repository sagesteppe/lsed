# Cluster sources into buffered, cell-capped regions for tiled cost distance

Lifted from the `Ecoloradense` cost-distance script. Builds `k` kmeans
clusters of the source points, then recursively bisects any cluster
whose bounding-box+buffer exceeds `max_cells`; returns one `SpatExtent`
per leaf. `seed` fixes the kmeans so splits are reproducible.

## Usage

``` r
cluster_region_extents(
  pts,
  k = 2,
  buffer_m = 3000,
  max_cells = NULL,
  res_m = NULL,
  seed = 1
)
```

## Arguments

- pts:

  sf points.

- k:

  initial kmeans clusters.

- buffer_m:

  buffer (metres) added around each cluster's bbox.

- max_cells:

  cap on a leaf's cropped-extent cell count; `NULL` disables recursion
  (exactly `k` clusters).

- res_m:

  raster resolution (metres/cell); required when `max_cells` is set.

- seed:

  kmeans seed; `NULL` leaves the RNG untouched.

## Value

a list of `SpatExtent`.

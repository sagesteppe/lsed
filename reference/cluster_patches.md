# Cluster patches into spatial groups

Groups patch centroids that lie within `eps_km` of one another (a
within-distance graph, connected components), so OSM can be fetched only
where patches actually are rather than across the empty country between
them.

## Usage

``` r
cluster_patches(patches, eps_km = 5, crs = NULL)
```

## Arguments

- patches:

  sf points or polygons.

- eps_km:

  join distance in km: patches within this of each other share a cluster
  (default `5`).

- crs:

  planar CRS (metres) for the distance test; defaults to the patches'
  CRS.

## Value

the patch centroids as sf points with a `cluster` id column.

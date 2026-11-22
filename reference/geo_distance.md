# Geographic distance from known populations (Dg)

Straight-line distance to the nearest source, rescaled to \\\[0, 1\]\\.

## Usage

``` r
geo_distance(sources, template, invert = FALSE)
```

## Arguments

- sources:

  source features (sf/`SpatVector`; points, lines or polys).

- template:

  `SpatRaster` giving the output grid.

- invert:

  if `TRUE`, return \\1 - \tilde d\\ (near = high), the index form.

## Value

a single-layer `SpatRaster` on \\\[0, 1\]\\.

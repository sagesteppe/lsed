# Scatter a per-suitable-cell label vector back into a raster

Build a `SpatRaster` aligned to `template`, with `vals` written at
`cells` and `NA` everywhere else.

## Usage

``` r
labels_to_raster(template, cells, vals, name = "unit")
```

## Arguments

- template:

  A `SpatRaster` whose geometry the result copies.

- cells:

  Integer global cell indices to fill.

- vals:

  Integer labels (same length as `cells`).

- name:

  Layer name for the result.

## Value

A single-layer integer `SpatRaster`.

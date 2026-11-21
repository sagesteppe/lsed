# Crop a raster to the bounding box of a cell set

[`terra::as.polygons`](https://rspatial.github.io/terra/reference/as.polygons.html)
scans the whole grid, so its cost tracks the raster *extent*, not the
number of data cells. When the data is spatially localised, cropping to
its bounding box first is a large speed-up; when it spans the whole
extent, cropping only adds overhead. The bounding box is computed
arithmetically from `cells` (no raster scan), and the crop is skipped
unless the box is smaller than `frac` of the full extent, so it never
hurts.

## Usage

``` r
crop_to_cells(x, cells, frac = 0.5)
```

## Arguments

- x:

  A `SpatRaster`.

- cells:

  Integer global cell indices of the data cells.

- frac:

  Crop only when the data bounding box is below this fraction of the
  full extent (default 0.5).

## Value

`x` cropped to the data bounding box, or `x` unchanged.

# Dissolve a label raster to polygons and attach attributes

Polygonise `id_rast` (one feature per id) and left-join `attrs` on the
id field. The id column of `attrs` must share the raster's layer name.

## Usage

``` r
polygonize_units(id_rast, attrs)
```

## Arguments

- id_rast:

  A `SpatRaster` of integer region ids.

- attrs:

  A data.frame of per-id attributes whose first/key column matches
  `names(id_rast)[1]`.

## Value

A `SpatVector` of polygons with the attributes merged in.

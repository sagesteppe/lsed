# Render the field to a raster view

Evaluates \\S(x)\\ at the cell centres of a template, tile by tile. This
is a *view* of the continuous model at a chosen resolution, not the
model itself — call it again at a different resolution for a different
view.

## Usage

``` r
survey_raster(
  field,
  template = NULL,
  res = NULL,
  rescale = c("quantile", "max", "none"),
  q = 0.95,
  invert = FALSE,
  filename = "",
  ...
)
```

## Arguments

- field:

  a `survey_field`.

- template:

  a terra `SpatRaster` whose geometry/CRS to match, or an `SpatExtent`;
  required alongside `res` when no template raster is given.

- res:

  cell size in map units when building from an extent (ignored if
  `template` is a `SpatRaster`).

- rescale:

  one of `"quantile"` (divide by the `q` quantile, clamped to 1; the
  default — `"max"` is hostage to a single survey hotspot, which
  flattens all other structure), `"max"` (divide by the max) or
  `"none"`, to bring the view onto \\\[0, 1\]\\.

- q:

  upper quantile for `rescale = "quantile"` (default `0.95`: about the
  top 5 percent of the surface saturates to 1, giving the sparsity
  surface its fullest dynamic range without one hotspot owning the
  scale).

- invert:

  if `TRUE`, return survey *sparsity* \\1 - \tilde S\\ (requires a
  `rescale` other than `"none"`); this is the form the `RankIndex`
  consumes.

- filename:

  optional output path (written via
  [`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html)).

- ...:

  passed to
  [`terra::writeRaster`](https://rspatial.github.io/terra/reference/writeRaster.html).

## Value

a single-layer `SpatRaster`.

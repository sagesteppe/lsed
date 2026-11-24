# Tobler walking-cost friction for accessibility (A)

An isotropic friction from Tobler's hiking function: walking speed \\W =
6\\e^{-3.5\\\|S + 0.05\|}\\ km/h on slope \\S\\ (rise/run), so cost per
unit distance is \\1/W\\. Symmetric (uses \\\|S\|\\) - appropriate for
access, which is a round trip. Feed to
[`cost_distance`](https://sagesteppe.github.io/lsed/reference/cost_distance.md)
from roads/trails.

## Usage

``` r
tobler_friction(dem)
```

## Arguments

- dem:

  elevation `SpatRaster` (projected, metres).

## Value

a `SpatRaster` of relative travel cost (higher = slower going).

# Read a cached raster when its signature matches, else compute and cache it

Internal memoiser: returns `terra::rast(tif)` when `tif`/`sigp` exist
and `sigp` holds `sig`; otherwise runs `fun()`, writes the result and
the signature (when `tif` is non-`NULL`), and returns it. A `NULL` `tif`
disables caching (always computes).

## Usage

``` r
cache_rast(tif, sigp, sig, fun)
```

## Arguments

- tif, sigp:

  Raster and signature sidecar paths, or `NULL` to skip caching.

- sig:

  Signature string recording the inputs.

- fun:

  Zero-arg function producing the `SpatRaster`.

## Value

The `SpatRaster`.

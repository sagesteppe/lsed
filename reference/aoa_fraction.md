# Majority-rule area-of-applicability fraction per region

Fraction of each region's cells that are in-domain (dissimilarity index
`<= aoa_thresh`); used with a 0.5 cut for a majority IN/OUT tag.

## Usage

``` r
aoa_fraction(di, id_rast, aoa_thresh = 1)
```

## Arguments

- di:

  A `SpatRaster` of the AOA dissimilarity index.

- id_rast:

  A `SpatRaster` of integer region ids.

- aoa_thresh:

  In-domain threshold (DI normalised to 1 by default).

## Value

A data.frame `id, frac_in_aoa`.

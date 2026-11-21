# Patch and subpatch delineation for survey-unit mapping

1.  [`delineate_patches`](https://sagesteppe.github.io/lsed/reference/delineate_patches.md)
    binarises the probability surface at a suitability threshold and
    runs a marker-controlled watershed (via WhiteboxTools) to break the
    suitable network at low necks, with a rook's-case component fallback
    for cells that drain off-mask, then drops sub-`min_area` slivers.
    This is the shared front end for both subdivision levers.

2.  [`band_subpatches`](https://sagesteppe.github.io/lsed/reference/band_subpatches.md)
    subdivides each oversized patch: it *contours* the raw surface into
    fixed suitability bands, finds same-band connected pieces (igraph
    components), *snaps* sub-threshold pieces into their highest-band
    contiguous neighbour
    ([`snap_pieces`](https://sagesteppe.github.io/lsed/reference/snap_pieces.md)),
    then geometrically caps any surviving unit still above the maximum
    size
    ([`kcap`](https://sagesteppe.github.io/lsed/reference/kcap.md)).

## Usage

``` r
M2_PER_ACRE
```

## Details

terra + whitebox for the raster/watershed work, igraph for the
connected-component and region-adjacency graphs
([`rook_edges`](https://sagesteppe.github.io/lsed/reference/rook_edges.md)
supplies the raster edge list; the greedy band-priority merge in
[`snap_pieces`](https://sagesteppe.github.io/lsed/reference/snap_pieces.md)
is the one graph step with no library primitive.

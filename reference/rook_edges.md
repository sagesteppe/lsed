# Rook's-case adjacency among a set of raster cells

East/south neighbour edges among a set of global cell indices, returned
as local index pairs (positions within `gc`). East+south only, since
each undirected rook edge is counted once from its lower-index endpoint.

## Usage

``` r
rook_edges(gc, nc, nr)
```

## Arguments

- gc:

  Integer vector of global (1-based) cell indices.

- nc, nr:

  Number of columns and rows in the parent raster.

## Value

A list with integer vectors `i` and `j`: local index pairs of adjacent
cells.

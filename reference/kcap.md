# Geometric k-means cap on a cell set

Split a set of cells into `ceil(n / capn)` compact pieces, each at or
below `capn` cells, by k-means on cell (col, row) positions; `k` is
bumped up until no cluster exceeds the cap (k-means targets equal sizes
but does not bound them). Sets under the cap pass through as a single
piece.

## Usage

``` r
kcap(gc, capn, nc)
```

## Arguments

- gc:

  Integer vector of global (1-based) cell indices.

- capn:

  Maximum pieces size in cells.

- nc:

  Number of columns in the parent raster (to recover col/row from `gc`).

## Value

Integer cluster label per cell (all `1L` when `n <= capn`).

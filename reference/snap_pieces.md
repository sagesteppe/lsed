# Snap sub-threshold band-pieces into their best contiguous neighbour

Sequential snap/merge over a region-adjacency graph: repeatedly absorb
each piece whose (accumulated) area is below its band's floor into its
contiguous neighbour, preferring the highest band and then the largest
area. The floor `minac[band]` **tightens as suitability rises**, so
small high-value ridge units survive while broad low aprons are cleaned
of slivers. Passes repeat until a pass makes no merges (or `npass` is
reached), letting chains collapse.

## Usage

``` r
snap_pieces(piece, ei, ej, area, band, minac, npass = 3L)
```

## Arguments

- piece:

  Integer vector (length = n cells) of band-piece labels `1..np` (e.g.
  from
  [`comp_labels`](https://sagesteppe.github.io/lsed/reference/comp_labels.md)
  on same-band edges).

- ei, ej:

  Integer vectors: *all* rook edges as local cell-index pairs (from
  [`rook_edges`](https://sagesteppe.github.io/lsed/reference/rook_edges.md));
  cross-piece edges define adjacency.

- area:

  Numeric vector (length `np`) of per-piece area (acres).

- band:

  Integer vector (length `np`) of per-piece band (1 low .. high).

- minac:

  Numeric vector of per-band minimum size (acres); a piece whose area is
  below `minac[band]` is a merge candidate.

- npass:

  Maximum number of snap passes.

## Value

Integer vector of length `np`: the resolved root piece for each piece.
Map per-cell with `root[piece]`.

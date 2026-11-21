# Connected components of a cell set from an edge subset

Thin wrapper over
[`components`](https://r.igraph.org/reference/components.html): label
`n` nodes `1..m` by connected component given an undirected edge subset.
Isolated nodes (no edge) each get their own label. Labels are re-mapped
to **first-appearance order** (node 1's component is 1, the next new
component is 2, ...) so the output is deterministic and independent of
igraph's internal traversal order – this keeps the downstream unit
numbering (and k-means-cap seed draws) stable across igraph versions.

## Usage

``` r
comp_labels(n, ei, ej)
```

## Arguments

- n:

  Number of nodes.

- ei, ej:

  Integer vectors of equal length: the endpoints (node indices) of each
  edge.

## Value

Integer vector of length `n` with component labels `1..m`.

# Combine the RankIndex terms into a priority score

Assembles \\\text{Rank}(x) = D_g + D_r + S + A + C\\ from whichever
terms you supply. Each term is a per-patch vector (patches in the same
order); the result is a data.frame of the rescaled components plus the
combined `index` and its `rank`.

## Usage

``` r
rank_index(..., weights = NULL, rescale = TRUE)
```

## Arguments

- ...:

  named per-patch term vectors, e.g.
  `Dg = dg, Dr = dr, S = s, A = a, C = c`; all equal length. A single
  named list or data.frame may be passed instead.

- weights:

  optional named numeric of per-term multipliers; names must match the
  supplied terms, partial is fine (unlisted terms get `1`).

- rescale:

  min-max each term to \\\[0,1\]\\ first (default `TRUE`).

## Value

a data.frame with one column per (rescaled) term, an `index` column (the
weighted-mean priority on \\\[0,1\]\\) and an integer `rank` (1 =
highest priority); the weights used are on attribute `weights`.

## Details

- **Rescaled.** Every input is min-max rescaled to \\\[0,1\]\\ so terms
  on different native scales are comparable before combining. (The term
  functions already emit \\\[0,1\]\\ and are oriented high = higher
  priority; this only guarantees it.) Set `rescale = FALSE` to trust the
  inputs as-is.

- **Weighted.** `weights` gives a per-term multiplier; unnamed terms
  default to `1` (all equal). The index is the **weighted mean** over
  the terms present for a patch, so it stays in \\\[0,1\]\\ and is
  comparable however many terms are included.

- **Skippable.** Only the terms you pass are used - drop `S` (or any
  other) simply by not supplying it.

- **NA-safe.** A patch missing one term is scored on its remaining terms
  (the weighted mean renormalises per row); a patch missing *every* term
  is `NA`.

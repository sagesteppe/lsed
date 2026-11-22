# Evaluate the field at arbitrary locations

Computes \\S(x)\\ at any set of query points — the whole point of
keeping the model gridless. Records are indexed into a `trunc`\\\sigma\\
bucket grid, and each query is summed only against records in its own
and the eight neighbouring buckets, so cost is local (\\\propto\\
records within support) regardless of how widely the queries are
scattered — not the query count times the record count.

## Usage

``` r
eval_survey(field, xy, species = NULL, chunk = 2048L)
```

## Arguments

- field:

  a `survey_field`.

- xy:

  two-column matrix/data.frame of query coordinates (same CRS as the
  records).

- species:

  optional subset of species labels; restricts the sum to those taxa
  (recovers a single additive layer, or any partial sum).

- chunk:

  unused; kept for back-compatibility.

## Value

numeric vector of \\S\\ values, length `nrow(xy)`.

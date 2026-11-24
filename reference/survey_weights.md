# Inverse-frequency species weights, corrected for domain clipping

Inverse-frequency species weights, corrected for domain clipping

## Usage

``` r
survey_weights(
  coords,
  species,
  domain = NULL,
  min_records = 5,
  p = 0.95,
  damp = 1
)
```

## Arguments

- coords:

  two-column matrix/data.frame of record coordinates (x, y) in the
  domain's planar CRS (metres).

- species:

  vector of species labels, one per record (length `nrow(coords)`).

- domain:

  the study domain as an sf polygon or a terra
  `SpatVector`/`SpatExtent`; `NULL` skips the correction (\\\varphi_j
  \equiv 1\\).

- min_records:

  minimum records a species needs to be included (default `5`). Taxa
  below the floor are dropped entirely - too few collections to carry a
  reliable range box or effort signal - not merely down-weighted.

- p:

  inner mass kept by the robust bounding box, as a central probability
  (default `0.95`); the box spans the `(1-p)/2` and `1-(1-p)/2`
  quantiles of x and y, trimming outlier records.

- damp:

  power applied to the raw weight \\\varphi_j/n_j\\ (default `1`; `0.5`
  softens the down-weighting of common taxa, `0` makes every species
  equal).

## Value

a `data.frame` with one row per species: `species`, `n` (records), `phi`
(\\\varphi_j\\), `freq` (\\f_j = n_j/\varphi_j\\) and `w` (the weight),
for species clearing `min_records`. Row order follows
`sort(unique(species))`.

## See also

[`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md)

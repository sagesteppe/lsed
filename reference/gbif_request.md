# Request a GBIF download (non-blocking) — stage 1 of 2

Submits the download predicate to GBIF and returns immediately with the
job key, **without** waiting for the server to prepare the archive. Do
other work (e.g. the OSM pull) while GBIF builds it, then collect with
[`gbif_retrieve`](https://sagesteppe.github.io/lsed/reference/gbif_retrieve.md).
Arguments mirror
[`gbif_records`](https://sagesteppe.github.io/lsed/reference/gbif_records.md).

## Usage

``` r
gbif_request(
  bbox,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  user = Sys.getenv("GBIF_USER"),
  pwd = Sys.getenv("GBIF_PWD"),
  email = Sys.getenv("GBIF_EMAIL")
)
```

## Arguments

- bbox:

  the area: an sf/terra object (extent used), or numeric
  `c(xmin, ymin, xmax, ymax)` in lon/lat.

- taxon_key:

  GBIF backbone key to restrict to (default `7707728`, Tracheophyta /
  vascular plants).

- basis:

  `basisOfRecord` values to keep (default preserved specimens + human
  observations).

- year_from:

  earliest year to keep (default `1990`); `NA` disables.

- coord_uncertainty_max:

  max coordinate uncertainty in metres (default `NA` = off, since the
  field is rarely populated); a number also drops records lacking the
  field.

- user, pwd, email:

  GBIF credentials (default the `GBIF_USER`/`GBIF_PWD`/ `GBIF_EMAIL`
  environment variables).

## Value

the `occ_download` job key (pass to
[`gbif_retrieve`](https://sagesteppe.github.io/lsed/reference/gbif_retrieve.md)).

## See also

[`gbif_retrieve`](https://sagesteppe.github.io/lsed/reference/gbif_retrieve.md),
[`gbif_records`](https://sagesteppe.github.io/lsed/reference/gbif_records.md)

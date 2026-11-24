# Fetch target-group occurrence records from GBIF for the survey-intensity term

Pulls occurrences inside a bounding box from GBIF as sf points, ready to
feed
[`survey_surface`](https://sagesteppe.github.io/lsed/reference/survey_surface.md)
as the target-group records for **S**. The pull uses GBIF's server-side
**bulk download**
([`rgbif::occ_download`](https://docs.ropensci.org/rgbif/reference/occ_download.html)) -
one prepared job rather than thousands of fragile paged requests, and
the route GBIF asks heavy users to take. `count_only = TRUE` first (no
account needed) to see the filtered total before committing.

## Usage

``` r
gbif_records(
  bbox,
  taxon_key = 7707728,
  basis = c("PRESERVED_SPECIMEN", "HUMAN_OBSERVATION"),
  year_from = 1990,
  coord_uncertainty_max = NA,
  crs = NULL,
  count_only = FALSE,
  path = NULL,
  download_dir = NULL,
  user = Sys.getenv("GBIF_USER"),
  pwd = Sys.getenv("GBIF_PWD"),
  email = Sys.getenv("GBIF_EMAIL"),
  poll = 30
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

- crs:

  output CRS (default lon/lat).

- count_only:

  if `TRUE`, return just the filtered record count - a cheap request, no
  account, no download.

- path:

  GeoPackage to write the records to (`NULL` -\> `gbif_records.gpkg` in
  the working directory).

- download_dir:

  where to save the GBIF download zip (`NULL` -\> beside `path`); kept
  so the costly job need not be re-run.

- user, pwd, email:

  GBIF credentials (default the `GBIF_USER`/`GBIF_PWD`/ `GBIF_EMAIL`
  environment variables).

- poll:

  seconds between status checks while the download is prepared (default
  `30`).

## Value

with `count_only`, an integer. Otherwise an sf of `POINT`s with
`speciesKey`, `species`, `basisOfRecord`,
`coordinateUncertaintyInMeters` and `year`; attributes `path` (file
written) and `doi` (citable download). Pass its coords + `speciesKey` to
[`survey_surface`](https://sagesteppe.github.io/lsed/reference/survey_surface.md).

## Details

**Requires a free GBIF account** for the download (not for the count).
Register at <https://www.gbif.org/>, then set `GBIF_USER`, `GBIF_PWD`
and `GBIF_EMAIL` (e.g. in `~/.Renviron`) or pass them as arguments. A
download is minted under your account and citable by its DOI.

**Filtering is the point.** A raw vascular-plant pull is swamped by
imprecise iNaturalist observations. `year_from` and
`coord_uncertainty_max` trim to records fit to mark *where a careful
collection happened*. The uncertainty filter also drops records with
*no* uncertainty recorded, which is most of them - so it defaults to
`NA` (off); set e.g. `100` only if you want to keep solely well-located
records.

## See also

[`survey_surface`](https://sagesteppe.github.io/lsed/reference/survey_surface.md)

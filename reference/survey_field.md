# Construct the survey-intensity field

Bundles the records, their per-record weights and the bandwidth into a
lightweight `survey_field` object that
[`eval_survey`](https://sagesteppe.github.io/lsed/reference/eval_survey.md)
and
[`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md)
evaluate. Nothing is discretised here.

## Usage

``` r
survey_field(
  coords,
  species,
  sigma = 100,
  record_type = NULL,
  plot_types = "Plot",
  plot_weight = 1,
  basis = NULL,
  basis_weights = c(PRESERVED_SPECIMEN = 1.5),
  weights = NULL,
  domain = NULL,
  min_records = 5,
  p = 0.95,
  damp = 1,
  trunc = 4
)
```

## Arguments

- coords:

  two-column matrix/data.frame of record coordinates (metres).

- species:

  vector of species labels (one per record).

- sigma:

  kernel bandwidth \\\sigma\\ in map units (metres), the radius over
  which one record counts ground as surveyed (default `100`).

- record_type:

  optional per-record label splitting the two detection processes.
  Records whose label is in `plot_types` are treated as **vegetation
  plots** — a complete floristic inventory at one spot (FIA, AIM,
  VegBank, ...), so absence there is strong evidence. Plot records are
  *deduplicated by coordinate* (the many species-rows of one plot are a
  single survey event, not many) and each surviving plot point carries
  `plot_weight`; they are also held out of the opportunistic frequency
  counts. `NULL` treats every record as opportunistic. See
  [`guess_record_type`](https://sagesteppe.github.io/lsed/reference/guess_record_type.md)
  to derive this from a dataset/origin column.

- plot_types:

  labels in `record_type` that mark a plot (default `"Plot"`, matched
  case-insensitively).

- plot_weight:

  per-record weight for a deduplicated plot point (default `1` — the
  ceiling of the opportunistic weights, which sit in \\(0, 1\]\\; raise
  it to let plots dominate further).

- basis:

  optional per-record `basisOfRecord` labels (as from `gbif_records`);
  used to up-weight deliberate collections.

- basis_weights:

  named multipliers applied per opportunistic record by its `basis`
  (default `c(PRESERVED_SPECIMEN = 1.5)` — a herbarium specimen marks
  survey effort ~50% more strongly than an iNaturalist photo). Any basis
  not named here is neutral (1); the \\n_j \ge 5\\ floor keeps even a
  boosted opportunistic weight below the plot ceiling.

- weights:

  optional per-species weights: a `data.frame` as returned by
  [`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)
  (matched on `species`), a named numeric vector, or `NULL` to compute
  them from `domain`/`min_records`/`p`/`damp`. Applied to the
  opportunistic records only.

- domain, min_records, p, damp:

  passed to
  [`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)
  when `weights` is `NULL`. Records of any species absent from the
  weight set — below the floor, or omitted by the caller — are dropped
  from the field.

- trunc:

  kernel support in units of \\\sigma\\ (default `4`).

## Value

an object of class `survey_field`: a list with `coords`, `species` (plot
points labelled `"__plot__"`), per-record `w`, `sigma`, `trunc`, the
opportunistic per-species `weights` table and `plot_weight`.

## See also

[`eval_survey`](https://sagesteppe.github.io/lsed/reference/eval_survey.md),
[`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md)

# Guess record type from a dataset / origin column

Flags records that come from structured **vegetation-plot** programmes -
where every species present is catalogued, so the record stands for a
complete local survey - by pattern-matching a free-text dataset,
institution or origin field. A convenience for when the user has not
labelled `record_type` by hand; always eyeball the result, since origin
strings are inconsistent.

## Usage

``` r
guess_record_type(
  origin,
  plot_patterns = c("vegbank", "\\bFIA\\b", "\\bAIM\\b", "\\bNEON\\b",
    "\\bCVS\\b", "carolina veg", "\\bNPS\\b", "rel[eé]v[eé]", "quadrat",
    "\\bplot\\b", "inventory"),
  plot_label = "Plot",
  other_label = "Opportunistic"
)
```

## Arguments

- origin:

  character (or factor) vector of dataset/origin labels, one per record.

- plot_patterns:

  case-insensitive regular expressions marking plot programmes. The
  defaults cover FIA, AIM, VegBank, NEON, the Carolina Vegetation
  Survey, NPS I&M, and generic plot/releve/quadrat/inventory wording;
  override or extend as needed.

- plot_label, other_label:

  labels returned for matches and non-matches (defaults `"Plot"` /
  `"Opportunistic"`); `NA` origins return `NA`.

## Value

a character vector the length of `origin`, suitable to pass as
`record_type`.

## See also

[`survey_surface`](https://sagesteppe.github.io/lsed/reference/survey_surface.md),
[`survey_field`](https://sagesteppe.github.io/lsed/reference/survey_field.md)

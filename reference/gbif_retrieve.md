# Retrieve a requested GBIF download - stage 2 of 2

Waits for the
[`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md)
job to finish preparing (usually already done if you did other work in
between), downloads the archive, imports it, and writes sf points.

## Usage

``` r
gbif_retrieve(key, path = NULL, download_dir = NULL, crs = NULL, poll = 30)
```

## Arguments

- key:

  the job key from
  [`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md).

- path, download_dir, crs, poll:

  as in
  [`gbif_records`](https://sagesteppe.github.io/lsed/reference/gbif_records.md).

## Value

an sf of points; attributes `path` and `doi`.

## See also

[`gbif_request`](https://sagesteppe.github.io/lsed/reference/gbif_request.md)

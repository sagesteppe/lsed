# Survey-intensity surface (the `S` term) as a continuous Gaussian field

Builds the manuscript's **survey intensity** term `S` - the “bias
surface” - from target-group occurrence records (a GBIF pull of
co-occurring taxa), as a continuous field of the landscape rather than a
grid. The estimator is a weighted sum of isotropic Gaussian kernels, one
per record:

## Details

\$\$S(x) \\=\\ \sum\_{j}\\ w_j \sum\_{i \in j} \exp\\\Big(-\frac{\lVert
x - p\_{ij} \rVert^2}{2\sigma^2}\Big),\$\$

where \\p\_{ij}\\ is record \\i\\ of species \\j\\, \\\sigma\\ is the
single search-radius bandwidth, and \\w_j\\ is a per-species weight.

**Why it is built this way**

- *Gridless / resolution-free.* \\S(x)\\ is a closed-form function of
  position, defined everywhere. Points are **never** binned to a grid
  before modelling; the model *is* the kernel sum. A raster is only ever
  a downstream *view* of the field, rendered at whatever resolution the
  user asks for
  ([`survey_raster`](https://sagesteppe.github.io/lsed/reference/survey_raster.md)),
  and two resolutions are two views of one model.

- *Additive across species.* The outer sum is over species, so each
  taxon contributes an independent layer \\w_j K_j(x)\\. A species can
  be added or dropped by adding/subtracting its term;
  [`eval_survey`](https://sagesteppe.github.io/lsed/reference/eval_survey.md)
  can be restricted to a subset of species to recover any single layer.

- *Inverse-frequency weighting, domain-corrected* (see
  [`survey_weights`](https://sagesteppe.github.io/lsed/reference/survey_weights.md)).
  Common taxa are uninformative about *effort* (they are everywhere); a
  record of a seldom-collected taxon marks a careful search. Let \\n_j\\
  be the record count and \\\varphi_j\\ the proportion of the species'
  **p95 bounding box** that falls inside the domain. The effective
  in-domain frequency is \\f_j = n_j / \varphi_j\\ and \\w_j =
  (\varphi_j / n_j)^{\mathrm{damp}}\\. The \\\varphi_j\\ correction
  stops a species whose range merely clips the domain edge from looking
  spuriously rare (and so over-weighted). Because \\\varphi_j \le 1 \le
  n_j\\, the raw weight \\w_j \in (0, 1\]\\ needs no cap: a
  fully-in-domain singleton earns the maximum weight 1, a common or
  edge-clipping taxon decays toward 0.

**Direction into the index.** Well-surveyed ground is *less* likely to
hide an undocumented population, so the `RankIndex` wants survey
*sparsity*: render with `invert = TRUE` to get \\1 - \tilde S\\, high
where nobody has looked.

terra for the raster view and sf for the p95-box/domain overlap. The
kernel is truncated at `trunc`\\\\\sigma\\ (tails below \\e^{-8}\\ at
`trunc = 4`) and evaluated with a tiled bounding-box prefilter, so no
kd-tree dependency and no \\k\\-neighbour cap - the sum is exact to the
tail.

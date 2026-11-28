#' Spatial residual diagnostics and residual-kriging correction for SDM predictions
#'
#' A small pipeline for the question a pooled decision curve cannot answer: are a
#' model's errors spatially structured, and if so can that structure be turned into
#' a bias-correction surface? Call \code{point_residuals()} to attach the signed
#' difference \eqn{y - \hat p} between observed occurrence and predicted suitability,
#' then \code{reduce_spatial_bias()} to run the rest end to end: fit a variogram to
#' the residuals, krige them (optionally with a bootstrap ensemble) onto a prediction
#' grid, and add that correction back onto the prediction raster. Depends on sf,
#' gstat, terra.
#'
#' The individual stages - \code{residual_variogram()}, \code{residual_krige()},
#' \code{bootstrap_correction()} and \code{apply_residual_correction()} - are
#' internal and driven by \code{reduce_spatial_bias()}.
#'
#' Sign convention throughout: a POSITIVE residual is a site the model UNDER-rates
#' (observed exceeds predicted); a negative residual is one it over-rates.
#'
#' The correction surface is only trustworthy where the model interpolates, so the
#' kriging stages take an \code{aoa} (a dissimilarity-index surface, in-AOA where
#' \code{di <= aoa_thresh}, or a polygon) and predict inside it only; outside the
#' AOA no correction is produced.

#' Restrict prediction locations to the area of applicability
#'
#' The AOA follows the package convention (see \code{aoa_fraction}): a raster
#' \code{aoa} is a CAST dissimilarity-index (DI) surface, in-AOA where
#' \code{di <= aoa_thresh}. A polygon \code{aoa} is taken as the in-AOA region
#' directly.
#'
#' @param newdata An \code{sf} point layer or a \code{terra} \code{SpatRaster}.
#' @param aoa The AOA as a \code{SpatRaster} dissimilarity-index surface (in-AOA
#'   where \code{di <= aoa_thresh}) or an \code{sf}/\code{SpatVector} polygon.
#'   \code{NULL} returns \code{newdata} unchanged.
#' @param aoa_thresh In-domain DI threshold for a raster \code{aoa} (default 1).
#' @param crs CRS to align a polygon \code{aoa} against (the points' CRS).
#'
#' @return \code{newdata} masked (raster) or filtered (points) to the AOA.
#' @keywords internal
restrict_to_aoa <- function(newdata, aoa, aoa_thresh = 1, crs = sf::st_crs(newdata)) {
  if (is.null(aoa)) return(newdata)
  if (inherits(newdata, "SpatRaster")) {
    if (inherits(aoa, "SpatRaster")) {
      m <- terra::ifel(aoa[[1]] <= aoa_thresh, 1, NA)
      if (!terra::compareGeom(newdata, m, stopOnError = FALSE))
        m <- terra::resample(m, newdata, method = "near")
      terra::mask(newdata, m)
    } else {
      terra::mask(newdata, if (inherits(aoa, "sf")) terra::vect(aoa) else aoa)
    }
  } else {
    if (inherits(aoa, "SpatRaster")) {
      v <- terra::extract(aoa[[1]], terra::vect(newdata))[[2]]
      newdata[is.finite(v) & v <= aoa_thresh, ]
    } else {
      av <- if (inherits(aoa, "SpatVector")) sf::st_as_sf(aoa) else aoa
      inside <- lengths(sf::st_intersects(newdata, sf::st_transform(av, sf::st_crs(newdata)))) > 0
      newdata[inside, ]
    }
  }
}

#' Signed residuals between observed occurrence and predicted suitability
#'
#' The residual is the difference \eqn{y - \hat p} on the suitability (probability)
#' scale, so it can be kriged and added straight back onto a prediction (see
#' \code{apply_residual_correction}). A POSITIVE residual is a site the model
#' UNDER-rates (observed exceeds predicted).
#'
#' @param points An \code{sf} point layer.
#' @param observed Column name in \code{points}, or a numeric 0/1 vector, of the
#'   observed occurrence.
#' @param predicted The predicted suitability: a \code{terra} \code{SpatRaster}
#'   (sampled at the points), a column name in \code{points}, or a numeric vector.
#' @param layer For a raster \code{predicted}, the layer to sample (name or index;
#'   default the first).
#'
#' @return \code{points} with added columns \code{pred} and \code{resid}.
#' @export
point_residuals <- function(points, observed, predicted, layer = 1) {
  y <- if (is.character(observed)) points[[observed]] else observed
  if (is.null(y)) stop("`observed` not found in `points`.")
  y <- as.numeric(y)

  if (inherits(predicted, "SpatRaster")) {
    ex <- terra::extract(predicted[[layer]], terra::vect(points))
    p <- ex[[ncol(ex)]]
  } else if (is.character(predicted)) {
    p <- as.numeric(points[[predicted]])
  } else {
    p <- as.numeric(predicted)
  }
  if (length(p) != length(y)) stop("`observed` and `predicted` lengths differ.")

  points$pred  <- p
  points$resid <- y - p
  points[is.finite(points$resid), ]
}

#' Empirical variogram of point residuals, with an optional fitted model
#'
#' @param points An \code{sf} point layer carrying a residual column.
#' @param resid Name of the residual column (default \code{"resid"}).
#' @param cutoff,width Passed to \code{\link[gstat]{variogram}}; defaults let gstat
#'   choose.
#' @param model Variogram model form for the fit, e.g. \code{"Exp"}, \code{"Sph"}.
#' @param fit Whether to fit \code{model} to the empirical variogram.
#' @param nugget_cut A field is flagged \code{pure_nugget} when the fitted nugget is
#'   at least this fraction of the total sill, or when the fit does not converge.
#'
#' @return A list with \code{empirical} (the gstat variogram data frame),
#'   \code{model} (the fitted model or \code{NULL}), \code{nugget}, \code{psill},
#'   \code{range}, \code{nugget_ratio}, \code{sample_var}, and \code{pure_nugget}.
#' @keywords internal
residual_variogram <- function(points, resid = "resid", cutoff = NULL, width = NULL,
                               model = "Exp", fit = TRUE, nugget_cut = 0.9) {
  f <- stats::as.formula(paste(resid, "~ 1"))
  args <- list(object = f, data = points)
  if (!is.null(cutoff)) args$cutoff <- cutoff
  if (!is.null(width))  args$width  <- width
  v <- do.call(gstat::variogram, args)
  sample_var <- stats::var(points[[resid]], na.rm = TRUE)

  m <- NULL; nugget <- NA_real_; psill <- NA_real_; rng <- NA_real_
  if (fit) {
    init <- gstat::vgm(psill = sample_var / 2, model = model,
                       range = max(v$dist) / 3, nugget = sample_var / 2)
    m <- tryCatch(gstat::fit.variogram(v, init), warning = function(w) NULL,
                  error = function(e) NULL)
    if (!is.null(m) && nrow(m) == 2) {
      nugget <- m$psill[1]; psill <- m$psill[2]; rng <- m$range[2]
    }
  }
  nugget_ratio <- if (is.finite(nugget) && is.finite(psill) && (nugget + psill) > 0)
    nugget / (nugget + psill) else NA_real_
  pure_nugget <- is.null(m) || is.na(nugget_ratio) || nugget_ratio >= nugget_cut

  list(empirical = v, model = m, nugget = nugget, psill = psill, range = rng,
       nugget_ratio = nugget_ratio, sample_var = sample_var, pure_nugget = pure_nugget)
}

#' Ordinary kriging of residuals onto new locations (the correction surface)
#'
#' @param points An \code{sf} point layer carrying a residual column.
#' @param newdata Where to predict: an \code{sf} point layer, or a \code{terra}
#'   \code{SpatRaster} template (non-\code{NA} cell centres are used and a raster is
#'   returned). Keep raster templates coarse - kriging every cell of a fine grid is
#'   expensive.
#' @param resid Name of the residual column (default \code{"resid"}).
#' @param model A fitted variogram model (e.g. \code{residual_variogram()$model}).
#' @param aoa Area-of-applicability restricting where the correction is produced: a
#'   \code{SpatRaster} dissimilarity-index surface (in-AOA where
#'   \code{di <= aoa_thresh}) or an \code{sf}/\code{SpatVector} polygon (see
#'   \code{restrict_to_aoa}). \code{NULL} predicts everywhere in \code{newdata}.
#' @param aoa_thresh In-domain DI threshold for a raster \code{aoa} (default 1).
#' @param ... Passed to \code{\link[gstat]{krige}} (e.g. \code{nmax}).
#'
#' @return \code{newdata} with the kriged correction (\code{var1.pred}) and variance
#'   (\code{var1.var}); a \code{SpatRaster} of both when \code{newdata} is a raster.
#'   Locations outside \code{aoa} are dropped (points) or \code{NA} (raster).
#' @keywords internal
residual_krige <- function(points, newdata, resid = "resid", model, aoa = NULL,
                           aoa_thresh = 1, ...) {
  if (is.null(model)) stop("`model` is NULL (pure nugget?) - nothing to interpolate.")
  f <- stats::as.formula(paste(resid, "~ 1"))
  newdata <- restrict_to_aoa(newdata, aoa, aoa_thresh, sf::st_crs(points))
  ras <- inherits(newdata, "SpatRaster")
  nd <- if (ras) {
    xy <- terra::crds(newdata[[1]], na.rm = TRUE)
    sf::st_as_sf(as.data.frame(xy), coords = c("x", "y"), crs = sf::st_crs(points))
  } else newdata
  k <- gstat::krige(f, points, nd, model = model, debug.level = 0, ...)
  if (!ras) return(k)
  tmpl <- terra::deepcopy(newdata[[1]]); terra::values(tmpl) <- NA
  cells <- terra::cellFromXY(tmpl, terra::crds(newdata[[1]], na.rm = TRUE))
  pred <- var <- tmpl
  pred[cells] <- k$var1.pred; var[cells] <- k$var1.var
  out <- c(pred, var); names(out) <- c("correction", "krige_var"); out
}

#' Bootstrap ensemble of the residual-kriging correction surface
#'
#' Resamples the points with replacement \code{n} times, re-krige each draw onto
#' \code{newdata}, and summarise the ensemble. Duplicate coordinates from resampling
#' are jittered slightly so the kriging system stays non-singular.
#'
#' @param points An \code{sf} point layer carrying a residual column.
#' @param newdata Prediction locations (\code{sf} points or a \code{SpatRaster}).
#' @param resid Name of the residual column (default \code{"resid"}).
#' @param model A fitted variogram model.
#' @param n Number of bootstrap resamples.
#' @param aoa Area-of-applicability restricting where the correction is produced (a
#'   DI \code{SpatRaster} or polygon; see \code{residual_krige}). \code{NULL}
#'   predicts everywhere.
#' @param aoa_thresh In-domain DI threshold for a raster \code{aoa} (default 1).
#' @param jitter Metres of jitter applied to resampled points to break ties.
#' @param seed Optional RNG seed. For \code{cores > 1} an L'Ecuyer-CMRG stream is
#'   used so the forked resamples are reproducible.
#' @param cores Worker processes for the resample loop, capped at \code{n}. Defaults
#'   to \code{getOption("mc.cores", 1L)} (serial unless you opt in). Uses
#'   \code{\link[parallel]{mclapply}}, which forks on Unix-alikes and degrades to
#'   serial on Windows.
#' @param ... Passed to \code{\link[gstat]{krige}}.
#'
#' @return \code{newdata} (or a \code{SpatRaster}) with the ensemble mean
#'   \code{corr_mean} and standard deviation \code{corr_sd} of the correction,
#'   restricted to \code{aoa}.
#' @keywords internal
bootstrap_correction <- function(points, newdata, resid = "resid", model, n = 199,
                                 aoa = NULL, aoa_thresh = 1, jitter = 1,
                                 seed = NULL, cores = NULL, ...) {
  if (is.null(model)) stop("`model` is NULL (pure nugget?), nothing to interpolate.")
  f <- stats::as.formula(paste(resid, "~ 1"))
  newdata <- restrict_to_aoa(newdata, aoa, aoa_thresh, sf::st_crs(points))
  ras <- inherits(newdata, "SpatRaster")
  nd <- if (ras) {
    xy <- terra::crds(newdata[[1]], na.rm = TRUE)
    sf::st_as_sf(as.data.frame(xy), coords = c("x", "y"), crs = sf::st_crs(points))
  } else newdata

  if (is.null(cores)) {
    cores <- getOption("mc.cores", 1L)
  }
  cores <- as.integer(max(1L, min(cores, n)))
  # mclapply cannot fork on Windows; restricted environments (R CMD check,
  # vignette knitting) cap usable cores via _R_CHECK_LIMIT_CORES_.
  if (.Platform$OS.type == "windows") {
    cores <- 1L
  }
  chk <- tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_", ""))
  if (nzchar(chk) && chk != "false") {
    cores <- min(cores, 2L)
  }
  if (!is.null(seed)) {
    if (cores > 1L) {
      old_kind <- RNGkind("L'Ecuyer-CMRG")
      on.exit(RNGkind(old_kind[1]), add = TRUE)
    }
    set.seed(seed)
  }

  one_boot <- function(b) {
    s <- points[sample.int(nrow(points), replace = TRUE), ]
    if (jitter > 0) s <- sf::st_jitter(s, amount = jitter)
    kb <- tryCatch(gstat::krige(f, s, nd, model = model, debug.level = 0, ...),
                   error = function(e) NULL)
    if (is.null(kb)) rep(NA_real_, nrow(nd)) else kb$var1.pred
  }
  reps <- if (cores > 1L) {
    parallel::mclapply(seq_len(n), one_boot, mc.cores = cores)
  } else {
    lapply(seq_len(n), one_boot)
  }
  mat <- do.call(cbind, reps)
  corr_mean <- rowMeans(mat, na.rm = TRUE)
  corr_sd   <- apply(mat, 1, stats::sd, na.rm = TRUE)

  if (!ras) {
    nd$corr_mean <- corr_mean; nd$corr_sd <- corr_sd; return(nd)
  }
  tmpl <- terra::deepcopy(newdata[[1]]); terra::values(tmpl) <- NA
  cells <- terra::cellFromXY(tmpl, terra::crds(newdata[[1]], na.rm = TRUE))
  mn <- sdv <- tmpl; mn[cells] <- corr_mean; sdv[cells] <- corr_sd
  out <- c(mn, sdv); names(out) <- c("corr_mean", "corr_sd"); out
}

#' Apply a residual correction to a prediction raster
#'
#' Adds a correction surface to predicted suitability and clamps to a valid range.
#' The correction is typically defined only inside the AOA (see
#' \code{residual_krige}); \code{outside} controls what happens to cells with no
#' correction.
#'
#' @param pred A \code{SpatRaster} of predicted suitability.
#' @param correction A \code{SpatRaster} correction (resampled to \code{pred} if their
#'   grids differ), \code{NA} outside the AOA.
#' @param clamp Range to clamp the corrected values to (default \code{c(0, 1)};
#'   \code{NULL} to skip).
#' @param outside What to do where \code{correction} is \code{NA}: \code{"keep"} the
#'   original prediction uncorrected (default), or \code{"na"} to blank those cells.
#'
#' @return A \code{SpatRaster} of corrected suitability.
#' @keywords internal
apply_residual_correction <- function(pred, correction, clamp = c(0, 1),
                                      outside = c("keep", "na")) {
  outside <- match.arg(outside)
  if (!terra::compareGeom(pred, correction, stopOnError = FALSE))
    correction <- terra::resample(correction, pred)
  out <- if (outside == "keep") pred + terra::ifel(is.na(correction), 0, correction)
         else pred + correction
  if (!is.null(clamp)) out <- terra::clamp(out, clamp[1], clamp[2])
  names(out) <- "suitability_corrected"
  out
}

#' Residual-kriging bias correction of a prediction raster, end to end
#'
#' The single entry point for the correction pipeline. Given points carrying signed
#' residuals (from \code{point_residuals}), it fits a variogram, krige the residuals
#' onto \code{newdata} (optionally as a bootstrap ensemble for uncertainty), and adds
#' the resulting correction surface back onto \code{pred}. When the residuals show no
#' spatial structure (a pure-nugget variogram) there is nothing to interpolate: the
#' function warns and returns \code{pred} unchanged.
#'
#' @param points An \code{sf} point layer carrying a residual column (see
#'   \code{\link{point_residuals}}).
#' @param newdata Where to krige the correction: an \code{sf} point layer or, more
#'   usually, a coarse \code{terra} \code{SpatRaster} template. Kriging every cell of
#'   a fine grid is expensive, so keep this coarser than \code{pred}.
#' @param pred A \code{SpatRaster} of predicted suitability to correct. Defaults to
#'   \code{newdata} when that is itself a raster.
#' @param resid Name of the residual column (default \code{"resid"}).
#' @param aoa Area-of-applicability restricting where the correction is produced: a
#'   \code{SpatRaster} dissimilarity-index (DI) surface (in-AOA where
#'   \code{di <= aoa_thresh}, the package convention) or an \code{sf}/\code{SpatVector}
#'   polygon. \code{NULL} predicts everywhere in \code{newdata}.
#' @param aoa_thresh In-domain DI threshold for a raster \code{aoa} (default 1).
#' @param bootstrap Whether to build the correction as a point-resampling ensemble
#'   (\code{n} draws) rather than a single kriging. The ensemble mean is used as the
#'   correction and its standard deviation is returned for uncertainty.
#' @param n Number of bootstrap resamples when \code{bootstrap = TRUE}.
#' @param cores Worker processes for the bootstrap (see \code{bootstrap_correction});
#'   ignored unless \code{bootstrap = TRUE}.
#' @param vgm_model Variogram model form to fit, e.g. \code{"Exp"}, \code{"Sph"}.
#' @param nugget_cut Nugget-to-sill ratio at or above which the field is treated as
#'   pure nugget (no spatial structure) and left uncorrected.
#' @param clamp Range to clamp the corrected values to (default \code{c(0, 1)};
#'   \code{NULL} to skip).
#' @param outside What to do where the correction is \code{NA} (outside the AOA):
#'   \code{"keep"} the original prediction (default) or \code{"na"} to blank it.
#' @param seed Optional RNG seed for the bootstrap.
#' @param ... Passed to \code{\link[gstat]{krige}} (e.g. \code{nmax}).
#'
#' @return A list with \code{corrected} (the corrected \code{SpatRaster}),
#'   \code{correction} (the kriged correction surface, or \code{NULL} when pure
#'   nugget) and \code{variogram} (the fitted-variogram diagnostics).
#' @seealso \code{\link{point_residuals}}
#' @export
reduce_spatial_bias <- function(points, newdata, pred = newdata, resid = "resid",
                                aoa = NULL, aoa_thresh = 1, bootstrap = FALSE,
                                n = 199, cores = NULL, vgm_model = "Exp",
                                nugget_cut = 0.9, clamp = c(0, 1),
                                outside = c("keep", "na"), seed = NULL, ...) {
  outside <- match.arg(outside)
  vg <- residual_variogram(points, resid = resid, model = vgm_model,
                           nugget_cut = nugget_cut)

  if (vg$pure_nugget) {
    warning("Residuals show no spatial structure (pure nugget); ",
            "returning `pred` uncorrected.")
    return(list(corrected = pred, correction = NULL, variogram = vg))
  }

  correction <- if (bootstrap) {
    bootstrap_correction(points, newdata, resid = resid, model = vg$model, n = n,
                         aoa = aoa, aoa_thresh = aoa_thresh, seed = seed,
                         cores = cores, ...)
  } else {
    residual_krige(points, newdata, resid = resid, model = vg$model, aoa = aoa,
                   aoa_thresh = aoa_thresh, ...)
  }

  corrected <- apply_residual_correction(pred, correction[[1]], clamp = clamp,
                                         outside = outside)
  list(corrected = corrected, correction = correction, variogram = vg)
}

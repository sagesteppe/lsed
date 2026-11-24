#' Net benefit of thresholded predictions at a target prevalence
#'
#' Decision-curve net benefit of treating (surveying) every unit whose predicted
#' probability is at least the threshold \code{pt}, case-weighted to a target
#' landscape prevalence with \code{\link{reweight}}:
#' \deqn{NB(p_t) = TP_w - FP_w \cdot \frac{p_t}{1 - p_t},}
#' where \eqn{TP_w} and \eqn{FP_w} are the prevalence-weighted true- and
#' false-positive fractions. This is the calibration-\emph{dependent} (per-point)
#' route: it thresholds the probabilities as given.
#'
#' @param truth Outcomes coded 1 (presence) / 0 (absence).
#' @param prob Predicted probabilities, same length as \code{truth}.
#' @param pi Target landscape prevalence in (0, 1).
#' @param pt Numeric vector of threshold probabilities.
#'
#' @return Numeric vector of net benefit, one per element of \code{pt}.
#' @seealso \code{\link{nb_binormal}} (best-achievable from an ROC),
#'   \code{\link{nb_treat_all}} (the treat-all reference).
#' @export
nb_exact <- function(truth, prob, pi, pt) {
  w <- reweight(truth, pi)
  n <- sum(w)
  vapply(
    pt,
    function(t) {
      pp <- prob >= t
      sum(w[pp & truth == 1]) / n - sum(w[pp & truth == 0]) / n * (t / (1 - t))
    },
    numeric(1)
  )
}

#' Bootstrap confidence band for the exact net-benefit curve
#'
#' Percentile bootstrap confidence limits for \code{\link{nb_exact}}, following
#' the extensions of Vickers et al. (2008). Resampling is \emph{stratified by
#' outcome} by default: presences and absences are resampled with replacement
#' separately so \eqn{n_1} and \eqn{n_0} -- and therefore the prevalence case
#' weights (\code{\link{reweight}}) -- stay fixed. This keeps the interval
#' consistent with the prevalence-invariant estimand, propagating only the
#' sampling noise in the within-class positive rates rather than in the sample's
#' own prevalence.
#'
#' Only a \emph{lower} band is returned by default. In decision-curve analysis
#' the operative question is whether the model is at least as good as the best
#' default strategy (treat-all or treat-none), so the decision-relevant
#' uncertainty is the downside; an upper limit changes no decision. Use
#' \code{side = "both"} for a two-sided interval.
#'
#' Bootstrap replicates are evaluated with \code{\link[parallel]{mclapply}},
#' which forks on Unix-alikes and falls back to serial execution on Windows. For
#' reproducible parallel runs set \code{RNGkind("L'Ecuyer-CMRG")} and a seed
#' before calling.
#'
#' @param truth Outcomes coded 1 (presence) / 0 (absence).
#' @param prob Predicted probabilities, same length as \code{truth}. These are
#'   assumed honest (held-out or cross-validated); the band quantifies precision,
#'   not optimism, and applies no overfit correction.
#' @param pi Target landscape prevalence in (0, 1).
#' @param pt Numeric vector of threshold probabilities.
#' @param B Number of bootstrap replicates. Default 999.
#' @param level Confidence level. Default 0.8.
#' @param side \code{"lower"} (default) for a one-sided lower band, or
#'   \code{"both"} for a two-sided interval.
#' @param stratified Resample within outcome classes (default \code{TRUE}) or
#'   over all observations (\code{FALSE}).
#' @param cores Number of worker processes, capped at \code{B}. Defaults to
#'   \code{getOption("mc.cores", 1L)}, i.e. serial unless you opt in. Parallel
#'   replicates use \code{\link[parallel]{mclapply}}, which forks on Unix-alikes
#'   only; on Windows, and in core-limited environments such as \code{R CMD
#'   check} and vignette knitting, execution falls back to serial (or at most two
#'   cores) regardless of this argument.
#'
#' @return A data frame with one row per \code{pt}: the threshold \code{pt}, the
#'   point estimate \code{nb}, and \code{lower} (plus \code{upper} when
#'   \code{side = "both"}).
#' @references Vickers AJ, Cronin AM, Elkin EB, Gonen M (2008). Extensions to
#'   decision curve analysis, a novel method for evaluating diagnostic tests,
#'   prediction models and molecular markers. \emph{BMC Med Inform Decis Mak}
#'   8:53.
#' @seealso \code{\link{nb_exact}}
#' @export
nb_exact_ci <- function(
  truth,
  prob,
  pi,
  pt,
  B = 999,
  level = 0.8,
  side = c("lower", "both"),
  stratified = TRUE,
  cores = NULL
) {
  side <- match.arg(side)
  est <- nb_exact(truth, prob, pi, pt)
  i1 <- which(truth == 1)
  i0 <- which(truth == 0)

  one_boot <- function(b) {
    idx <- if (stratified) {
      c(sample(i1, replace = TRUE), sample(i0, replace = TRUE))
    } else {
      sample(length(truth), replace = TRUE)
    }
    nb_exact(truth[idx], prob[idx], pi, pt)
  }

  if (is.null(cores)) {
    cores <- getOption("mc.cores", 1L)
  }
  cores <- as.integer(max(1L, min(cores, B)))
  # mclapply cannot fork on Windows; restricted environments (R CMD check,
  # vignette knitting) cap usable cores via _R_CHECK_LIMIT_CORES_.
  if (.Platform$OS.type == "windows") {
    cores <- 1L
  }
  chk <- tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_", ""))
  if (nzchar(chk) && chk != "false") {
    cores <- min(cores, 2L)
  }

  reps <- if (cores > 1L) {
    parallel::mclapply(seq_len(B), one_boot, mc.cores = cores)
  } else {
    lapply(seq_len(B), one_boot)
  }
  boot <- do.call(rbind, reps)

  a <- 1 - level
  lo <- if (side == "lower") a else a / 2
  out <- data.frame(
    pt = pt,
    nb = est,
    lower = apply(
      boot,
      2,
      stats::quantile,
      probs = lo,
      na.rm = TRUE,
      names = FALSE
    )
  )
  if (side == "both") {
    out$upper <- apply(
      boot,
      2,
      stats::quantile,
      probs = 1 - a / 2,
      na.rm = TRUE,
      names = FALSE
    )
  }
  out
}

#' Best-achievable net benefit from an equal-variance binormal ROC
#'
#' Net benefit read off an equal-variance binormal ROC (separation \code{mu}) at
#' the operating point whose slope equals the cost ratio
#' \code{((1 - pi) / pi) * (pt / (1 - pt))}. Because it always uses the optimal
#' cutoff, this is the calibration-\emph{independent}, best-achievable net benefit
#' for that ROC -- the summary-metric counterpart of \code{\link{nb_exact}}.
#'
#' @param mu Binormal separation (>= 0).
#' @param pi Target landscape prevalence in (0, 1).
#' @param pt Numeric vector of threshold probabilities.
#'
#' @return Numeric vector of net benefit, one per element of \code{pt}.
#' @export
nb_binormal <- function(mu, pi, pt) {
  vapply(
    pt,
    function(t) {
      m <- ((1 - pi) / pi) * (t / (1 - t)) # target ROC slope for this threshold
      cc <- (log(m) + mu^2 / 2) / mu # score cutoff giving that slope
      pi * pnorm(mu - cc) - (1 - pi) * pnorm(-cc) * (t / (1 - t))
    },
    numeric(1)
  )
}

#' Plausibility band for a binormal net-benefit curve from PR-AUC uncertainty
#'
#' The summary route (\code{\link{nb_binormal}}) anchors an entire decision curve
#' to a single reported PR-AUC, almost always a point estimate with no stated
#' uncertainty. This propagates a plausible \emph{spread} in that PR-AUC into a band
#' on the net-benefit curve, extending \code{\link{ap_scalar_to_prev}} from a point
#' reconstruction to an interval one.
#'
#' The perturbation is anchored on the PR-AUC scale, not on \code{mu} directly: a
#' fixed shift in \code{mu} has no stable meaning across taxa or prevalences,
#' whereas a spread in PR-AUC is what replicate train/test partitions actually show.
#' The reported PR-AUC and its \code{spread}-perturbed endpoints are each converted
#' to a binormal separation by inverting \code{\link{ap_binormal}} at the evaluation
#' prevalence \code{pi0}, then read off \code{\link{nb_binormal}} at the target
#' prevalence. Because \code{nb_binormal} is monotone increasing in \code{mu}, the
#' PR-AUC endpoints map straight to the band edges.
#'
#' This is a \emph{plausibility} band (a sensitivity analysis over an assumed
#' PR-AUC spread), not a confidence interval: with only a reported scalar there is
#' no sampling distribution. Calibrate \code{spread} from replicate models when you
#' have them; see \code{\link{nb_exact_ci}} for the model-free sampling band when
#' raw predictions are available.
#'
#' Only a \emph{lower} band is returned by default, matching
#' \code{\link{nb_exact_ci}}: in decision-curve analysis the decision-relevant
#' uncertainty is the downside -- whether the model could be worse than a default
#' strategy. Use \code{side = "both"} for upper and lower edges.
#'
#' @param pr_auc Reported PR-AUC (average precision) at the evaluation prevalence,
#'   a single value.
#' @param pi Target landscape prevalence in (0, 1).
#' @param pt Numeric vector of threshold probabilities.
#' @param spread Half-width of the plausible PR-AUC range, in PR-AUC units
#'   (e.g. \code{0.04} for +/- 0.04). Calibrate from replicate-model spread.
#' @param side \code{"lower"} (default) for a one-sided lower band, or
#'   \code{"both"} for lower and upper edges.
#' @param pi0 Evaluation prevalence the PR-AUC was measured at. Defaults to
#'   \code{pi}.
#' @param grid Integration grid passed to \code{\link{ap_binormal}} when inverting
#'   the PR-AUC.
#'
#' @return A data frame with one row per \code{pt}: \code{pt}, the central curve
#'   \code{nb}, and \code{lower} (plus \code{upper} when \code{side = "both"}).
#'   The fitted separations are attached as attribute \code{"mu"} (named
#'   \code{central}, \code{lower}, and \code{upper} when two-sided).
#' @seealso \code{\link{nb_binormal}}, \code{\link{nb_exact_ci}},
#'   \code{\link{ap_scalar_to_prev}}
#' @export
nb_binormal_band <- function(
  pr_auc,
  pi,
  pt,
  spread,
  side = c("lower", "both"),
  pi0 = pi,
  grid = 3000
) {
  side <- match.arg(side)
  to_mu <- function(val) {
    val <- min(max(val, 1e-4), 1 - 1e-4)
    stats::uniroot(
      function(m) ap_binormal(m, pi0, grid = grid) - val,
      c(1e-3, 8)
    )$root
  }
  mu <- c(central = to_mu(pr_auc), lower = to_mu(pr_auc - spread))
  out <- data.frame(
    pt = pt,
    nb = nb_binormal(mu[["central"]], pi, pt),
    lower = nb_binormal(mu[["lower"]], pi, pt)
  )
  if (side == "both") {
    mu <- c(mu, upper = to_mu(pr_auc + spread))
    out$upper <- nb_binormal(mu[["upper"]], pi, pt)
  }
  attr(out, "mu") <- mu
  out
}

#' Net benefit of the treat-all (survey-everything) reference strategy
#'
#' The decision-curve reference that acts on every unit:
#' \code{pi - (1 - pi) * (pt / (1 - pt))}. Treat-none is identically 0.
#'
#' @param pi Prevalence in (0, 1).
#' @param pt Numeric vector of threshold probabilities.
#'
#' @return Numeric vector of net benefit, one per element of \code{pt}.
#' @export
nb_treat_all <- function(pi, pt) {
  pi - (1 - pi) * (pt / (1 - pt))
}

#' lsed: Prevalence-corrected evaluation of species-distribution predictions
#'
#' Helper functions behind the decision-curve manuscript: case weights that
#' re-price an evaluation sample to a target landscape prevalence, the
#' prevalence-invariant ROC-AUC, average-precision and net-benefit summaries
#' (both the exact point-level route and the equal-variance binormal route),
#' and Cox calibration of held-out predictions.
#'
#' @keywords internal
#' @importFrom stats glm binomial coef qlogis plogis pnorm qnorm uniroot setNames
#' @importFrom utils head tail
"_PACKAGE"

#' Combine the RankIndex terms into a priority score
#'
#' Assembles \eqn{\text{Rank}(x) = D_g + D_r + S + A + C} from whichever terms you
#' supply. Each term is a per-patch vector (patches in the same order); the result is a
#' data.frame of the rescaled components plus the combined \code{index} and its
#' \code{rank}.
#'
#' \itemize{
#'   \item \strong{Rescaled.} Every input is min–max rescaled to \eqn{[0,1]} so terms
#'     on different native scales are comparable before combining. (The term functions
#'     already emit \eqn{[0,1]} and are oriented high = higher priority; this only
#'     guarantees it.) Set \code{rescale = FALSE} to trust the inputs as-is.
#'   \item \strong{Weighted.} \code{weights} gives a per-term multiplier; unnamed terms
#'     default to \code{1} (all equal). The index is the \strong{weighted mean} over
#'     the terms present for a patch, so it stays in \eqn{[0,1]} and is comparable
#'     however many terms are included.
#'   \item \strong{Skippable.} Only the terms you pass are used — drop \code{S} (or any
#'     other) simply by not supplying it.
#'   \item \strong{NA-safe.} A patch missing one term is scored on its remaining terms
#'     (the weighted mean renormalises per row); a patch missing \emph{every} term is
#'     \code{NA}.
#' }
#'
#' @param ... named per-patch term vectors, e.g. \code{Dg = dg, Dr = dr, S = s,
#'   A = a, C = c}; all equal length. A single named list or data.frame may be passed
#'   instead.
#' @param weights optional named numeric of per-term multipliers; names must match the
#'   supplied terms, partial is fine (unlisted terms get \code{1}).
#' @param rescale min–max each term to \eqn{[0,1]} first (default \code{TRUE}).
#' @return a data.frame with one column per (rescaled) term, an \code{index} column
#'   (the weighted-mean priority on \eqn{[0,1]}) and an integer \code{rank}
#'   (1 = highest priority); the weights used are on attribute \code{weights}.
#' @export
rank_index <- function(..., weights = NULL, rescale = TRUE) {
  terms <- list(...)
  if (length(terms) == 1L && is.null(names(terms)) &&
      (is.data.frame(terms[[1]]) || is.list(terms[[1]])))
    terms <- as.list(terms[[1]])

  nm <- names(terms)
  if (!length(terms) || is.null(nm) || any(!nzchar(nm)))
    stop("supply at least one *named* term vector (e.g. Dg = ..., A = ...)")
  if (length(unique(lengths(terms))) != 1L)
    stop("all terms must have the same length (one value per patch, same order)")

  M <- vapply(terms, as.numeric, numeric(length(terms[[1]])))
  if (!is.matrix(M)) M <- matrix(M, ncol = length(terms), dimnames = list(NULL, nm))
  if (rescale) M <- apply(M, 2, .rsc01)

  w <- stats::setNames(rep(1, ncol(M)), nm)
  if (!is.null(weights)) {
    bad <- setdiff(names(weights), nm)
    if (length(bad)) stop("weights for terms not supplied: ", paste(bad, collapse = ", "))
    w[names(weights)] <- as.numeric(weights)
  }

  # Weighted mean over the terms present per patch (renormalise where some are NA).
  W <- matrix(w, nrow(M), ncol(M), byrow = TRUE); W[is.na(M)] <- NA
  den <- rowSums(W, na.rm = TRUE)
  index <- rowSums(W * M, na.rm = TRUE) / den
  index[den == 0] <- NA_real_

  out <- data.frame(M, index = index, rank = rank(-index, ties.method = "min",
                                                  na.last = "keep"),
                    check.names = FALSE)
  attr(out, "weights") <- w
  out
}

# Min-max rescale to [0, 1], NA-safe; a constant (or all-NA) column -> 0 (neutral,
# contributes nothing to the ranking).
.rsc01 <- function(x) {
  r <- range(x, na.rm = TRUE)
  if (!is.finite(r[1]) || !is.finite(r[2]) || r[2] <= r[1]) return(x * 0)
  (x - r[1]) / (r[2] - r[1])
}

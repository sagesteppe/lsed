#' Resolve a worker-process count for forked parallelism
#'
#' Shared helper for the bootstrap routines (\code{\link{nb_exact_ci}},
#' \code{bootstrap_correction}). Defaults a \code{NULL} request to
#' \code{getOption("mc.cores", 1L)}, caps it at the number of independent jobs, forces
#' serial on Windows (\code{\link[parallel]{mclapply}} cannot fork there) and honours
#' \code{_R_CHECK_LIMIT_CORES_} (set during R CMD check and vignette knitting), which
#' caps usable cores at 2.
#'
#' @param cores Requested worker count, or \code{NULL} to read
#'   \code{getOption("mc.cores", 1L)}.
#' @param cap Upper bound on the count (the number of independent jobs).
#'
#' @return An integer worker count, at least 1.
#' @keywords internal
resolve_cores <- function(cores, cap) {
  if (is.null(cores)) {
    cores <- getOption("mc.cores", 1L)
  }
  cores <- as.integer(max(1L, min(cores, cap)))
  if (.Platform$OS.type == "windows") {
    cores <- 1L
  }
  chk <- tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_", ""))
  if (nzchar(chk) && chk != "false") {
    cores <- min(cores, 2L)
  }
  cores
}

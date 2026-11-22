skip_if_not_installed("igraph")

# A tiny hand-built patch graph lets us test complementarity()'s accounting and the
# cap_q clamp directly, without the sf/sfnetworks accessibility front end.
#   p1 - p2 - p3 - p4  (unit edges)   and   p4 --(100)-- p5   (one far outlier)
make_net <- function(long = 100) {
  e <- data.frame(
    from   = c("patch_1", "patch_2", "patch_3", "patch_4"),
    to     = c("patch_2", "patch_3", "patch_4", "patch_5"),
    weight = c(1, 1, 1, long)
  )
  list(graph = igraph::graph_from_data_frame(e, directed = FALSE))
}

test_that("complementarity assembly cost is the travel to gather target_area", {
  pn <- paste0("patch_", 1:5)
  # each patch is 30 acres, target 50 -> must reach exactly one neighbour
  res <- complementarity(make_net(), pn, areas = rep(30, 5),
                         target_area = 50, cap_q = NULL)
  expect_equal(res$patch_node, pn)
  # p1..p4 each have a unit-distance neighbour; p5's nearest is p4 at 100
  expect_equal(res$assemble_hr, c(1, 1, 1, 1, 100))
  expect_true(all(res$C >= 0 & res$C <= 1))
})

test_that("cap_q clamps the right tail before rescaling", {
  pn <- paste0("patch_", 1:5)
  res <- complementarity(make_net(), pn, areas = rep(30, 5),
                         target_area = 50, cap_q = 0.8)
  cap <- stats::quantile(c(1, 1, 1, 1, 100), 0.8, names = FALSE)
  expect_equal(max(res$assemble_hr), cap)      # outlier pulled down to the quantile
  expect_equal(res$assemble_hr[5], cap)
  expect_equal(res$assemble_hr[1:4], c(1, 1, 1, 1))  # below-cap costs untouched
})

test_that("unreachable patches: capped to a finite worst value, else max finite", {
  pn <- paste0("patch_", 1:5)
  # disconnect p5 entirely -> it can never gather target_area (Inf)
  g <- igraph::graph_from_data_frame(
    data.frame(from = c("patch_1", "patch_2", "patch_3"),
               to   = c("patch_2", "patch_3", "patch_4"),
               weight = c(1, 1, 1)),
    directed = FALSE,
    vertices = data.frame(name = pn))
  net <- list(graph = g)

  # no cap: Inf falls back to the worst finite cost (1 here)
  nocap <- complementarity(net, pn, areas = rep(30, 5),
                           target_area = 50, cap_q = NULL)
  expect_true(all(is.finite(nocap$assemble_hr)))
  expect_equal(nocap$assemble_hr[5], max(nocap$assemble_hr[1:4]))

  # with cap: Inf is clamped to the quantile too (all costs equal here -> constant)
  capped <- complementarity(net, pn, areas = rep(30, 5), target_area = 50, cap_q = 0.95)
  expect_true(all(is.finite(capped$assemble_hr)))
})

test_that("cap_q is validated", {
  pn <- paste0("patch_", 1:5)
  expect_error(complementarity(make_net(), pn, areas = rep(30, 5), cap_q = 1.5))
  expect_error(complementarity(make_net(), pn, areas = rep(30, 5), cap_q = 0))
  # areas length must match patch_nodes
  expect_error(complementarity(make_net(), pn, areas = rep(30, 4)))
})

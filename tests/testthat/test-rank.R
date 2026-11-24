test_that("rank_index rescales, weights, and ranks", {
  out <- rank_index(Dg = c(0, 5, 10), A = c(1, 1, 1))
  # Dg rescales to 0,0.5,1; A is constant -> 0 (neutral)
  expect_equal(out$Dg, c(0, 0.5, 1))
  expect_equal(out$A, c(0, 0, 0))
  # equal weights, weighted mean over both terms
  expect_equal(out$index, c(0, 0.25, 0.5))
  # highest index = rank 1
  expect_equal(out$rank, c(3L, 2L, 1L))
  expect_equal(unname(attr(out, "weights")), c(1, 1))
})

test_that("rank_index honours weights and renormalises per row on NA", {
  # A missing for patch 2 -> scored on Dg alone there
  out <- rank_index(Dg = c(0, 1), A = c(NA, 0), weights = c(Dg = 3))
  expect_equal(unname(attr(out, "weights")), c(3, 1))
  # row 1: only Dg present (0) -> 0 ; row 2: (3*1 + 1*0)/4 = 0.75
  expect_equal(out$index, c(0, 0.75))
})

test_that("rank_index: a patch missing every term is NA", {
  out <- rank_index(Dg = c(NA, 1), A = c(NA, 0))
  expect_true(is.na(out$index[1]))
  expect_true(is.na(out$rank[1]))
})

test_that("rank_index accepts a single named list and rejects bad weights", {
  expect_equal(rank_index(list(Dg = c(0, 1)))$index, c(0, 1))
  expect_error(rank_index(Dg = c(0, 1), weights = c(Zz = 2)), "not supplied")
  expect_error(rank_index(c(0, 1)), "named")
})

test_that("rank_index rejects terms of unequal length", {
  expect_error(rank_index(Dg = c(1, 2), A = c(1, 2, 3)), "same length")
})

test_that("rank_index handles a single patch (length-1 terms)", {
  # the one-row reshape: terms are scalars, so M starts as a vector and is matrixified;
  # rescale of a single value is neutral (0), index 0, the sole patch ranks 1
  out <- rank_index(Dg = 0.5, A = 0.2)
  expect_equal(nrow(out), 1L)
  expect_true(all(c("Dg", "A", "index", "rank") %in% names(out)))
  expect_equal(out$index, 0)
  expect_equal(out$rank, 1L)
})

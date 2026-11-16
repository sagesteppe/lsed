test_that("weights sum to 1", {
  truth <- c(1, 0, 0, 1, 0, 1, 0, 0)
  expect_equal(sum(reweight(truth, pi = 0.05)), 1)
  expect_equal(sum(reweight(truth, pi = 0.5)),  1)
})

test_that("class totals equal the target prevalence split", {
  truth <- c(1, 0, 0, 1, 0, 1, 0, 0)
  pi <- 0.05
  w <- reweight(truth, pi)
  expect_equal(sum(w[truth == 1]), pi)
  expect_equal(sum(w[truth == 0]), 1 - pi)
})

test_that("every case in a class gets the same weight", {
  truth <- c(1, 0, 0, 1, 0, 1, 0, 0)
  pi <- 0.2
  n1 <- sum(truth == 1); n0 <- sum(truth == 0)
  w <- reweight(truth, pi)
  expect_true(all(w[truth == 1] == pi / n1))
  expect_true(all(w[truth == 0] == (1 - pi) / n0))
})

test_that("output is aligned to the input length and order", {
  truth <- c(1, 0, 1)
  w <- reweight(truth, 0.3)
  expect_length(w, length(truth))
  # reordering the input reorders the output identically
  o <- c(3, 1, 2)
  expect_equal(reweight(truth[o], 0.3), w[o])
})

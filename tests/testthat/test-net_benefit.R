test_that("treat-all matches its closed form and is zero at pt = pi", {
  pi <- 0.1
  pt <- c(0.02, 0.05, 0.1, 0.2)
  expect_equal(nb_treat_all(pi, pt), pi - (1 - pi) * (pt / (1 - pt)))
  # treating everyone breaks even exactly when the threshold equals prevalence
  expect_equal(nb_treat_all(pi, pi), 0)
})

test_that("nb_exact is vectorised over pt and bounded above by prevalence", {
  set.seed(10)
  truth <- rbinom(300, 1, 0.3)
  prob  <- plogis(-0.8 + 1.5 * truth + rnorm(300))
  pt <- c(0.02, 0.05, 0.1, 0.2, 0.3)
  nb <- nb_exact(truth, prob, pi = 0.05, pt = pt)
  expect_length(nb, length(pt))
  expect_true(all(nb <= 0.05 + 1e-9))   # net benefit can never exceed prevalence
})

test_that("nb_exact collapses to treat-all when everyone is flagged", {
  # prob = 1 >= every pt < 1, so all units are 'treated' -> treat-all net benefit
  truth <- c(1, 0, 0, 1, 0, 0, 0, 1, 0, 0)
  pt <- c(0.02, 0.1, 0.25)
  pi <- 0.08
  expect_equal(nb_exact(truth, rep(1, length(truth)), pi, pt),
               nb_treat_all(pi, pt))
})

test_that("nb_exact is zero when no unit clears the threshold", {
  truth <- c(1, 0, 0, 1, 0)
  expect_equal(nb_exact(truth, rep(0, 5), pi = 0.1, pt = c(0.3, 0.5)),
               c(0, 0))
})

test_that("nb_binormal is vectorised, finite, and improves with separation", {
  pi <- 0.1
  pt <- c(0.05, 0.1, 0.2)
  nb0 <- nb_binormal(mu = 0.5, pi, pt)
  nb1 <- nb_binormal(mu = 2.0, pi, pt)
  expect_length(nb0, length(pt))
  expect_true(all(is.finite(nb0)))
  expect_true(all(nb1 >= nb0 - 1e-9))   # more separable ROC is never worse
})

test_that("the best-achievable curve dominates treat-all", {
  pi <- 0.1
  pt <- c(0.05, 0.1, 0.2, 0.3)
  expect_true(all(nb_binormal(mu = 1.5, pi, pt) >= nb_treat_all(pi, pt) - 1e-9))
})

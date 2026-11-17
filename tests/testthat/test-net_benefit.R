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

test_that("nb_exact_ci returns a lower band around the point estimate", {
  set.seed(1)
  truth <- rbinom(400, 1, 0.3)
  prob  <- plogis(-0.8 + 1.5 * truth + rnorm(400))
  pt <- c(0.02, 0.05, 0.1, 0.2)
  ci <- nb_exact_ci(truth, prob, pi = 0.05, pt = pt, B = 199, cores = 1)
  expect_s3_class(ci, "data.frame")
  expect_equal(ci$pt, pt)
  expect_equal(ci$nb, nb_exact(truth, prob, pi = 0.05, pt = pt))
  expect_true(all(ci$lower <= ci$nb + 1e-9))   # lower band sits below the point
  expect_false("upper" %in% names(ci))
})

test_that("nb_exact_ci two-sided brackets the point estimate and widens", {
  set.seed(2)
  truth <- rbinom(400, 1, 0.3)
  prob  <- plogis(-0.8 + 1.5 * truth + rnorm(400))
  pt <- c(0.05, 0.1, 0.2)
  ci80 <- nb_exact_ci(truth, prob, 0.05, pt, B = 299, level = 0.8,
                      side = "both", cores = 1)
  ci95 <- nb_exact_ci(truth, prob, 0.05, pt, B = 299, level = 0.95,
                      side = "both", cores = 1)
  expect_true(all(ci80$lower <= ci80$nb + 1e-9))
  expect_true(all(ci80$upper >= ci80$nb - 1e-9))
  # higher confidence -> wider (or equal) interval
  expect_true(all((ci95$upper - ci95$lower) >= (ci80$upper - ci80$lower) - 1e-9))
})

test_that("nb_binormal_band brackets the central curve, lower-only by default", {
  pi0 <- 0.1; pi <- 0.05
  pt <- c(0.02, 0.05, 0.1, 0.2)
  pr <- ap_binormal(mu = 1.5, pi0, grid = 3000)
  b <- nb_binormal_band(pr, pi = pi, pt = pt, spread = 0.03, pi0 = pi0)
  expect_true(all(b$lower <= b$nb + 1e-9))
  expect_false("upper" %in% names(b))                  # lower-only default
  bb <- nb_binormal_band(pr, pi, pt, spread = 0.03, pi0 = pi0, side = "both")
  expect_true(all(bb$upper >= bb$nb - 1e-9))
  mu <- attr(bb, "mu")
  expect_true(mu[["lower"]] < mu[["central"]] && mu[["central"]] < mu[["upper"]])
  # wider PR-AUC spread -> wider band
  bw <- nb_binormal_band(pr, pi, pt, spread = 0.06, pi0 = pi0, side = "both")
  expect_true(all((bw$upper - bw$lower) >= (bb$upper - bb$lower) - 1e-9))
})

test_that("nb_binormal_band inverts PR-AUC through ap_binormal at pi0", {
  pi0 <- 0.1; pi <- 0.03
  pt <- c(0.02, 0.05, 0.1)
  pr <- ap_binormal(mu = 1.2, pi0, grid = 3000)
  b <- nb_binormal_band(pr, pi = pi, pt = pt, spread = 0.02, pi0 = pi0)
  # central mu recovers the generating separation and prices NB at the target pi
  expect_equal(attr(b, "mu")[["central"]], 1.2, tolerance = 1e-2)
  expect_equal(b$nb, nb_binormal(attr(b, "mu")[["central"]], pi, pt))
})

test_that("the best-achievable curve dominates treat-all", {
  pi <- 0.1
  pt <- c(0.05, 0.1, 0.2, 0.3)
  expect_true(all(nb_binormal(mu = 1.5, pi, pt) >= nb_treat_all(pi, pt) - 1e-9))
})

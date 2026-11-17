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

test_that("nb_exact_ci point estimate and columns match nb_exact exactly", {
  set.seed(11)
  truth <- rbinom(200, 1, 0.3)
  prob  <- plogis(-0.8 + 1.5 * truth + rnorm(200))
  pt <- c(0.02, 0.05, 0.1, 0.2)
  ci <- nb_exact_ci(truth, prob, 0.05, pt, B = 199, cores = 1)
  expect_equal(ci$pt, pt)
  expect_equal(ci$nb, nb_exact(truth, prob, 0.05, pt))   # central is the plug-in estimate
  expect_named(ci, c("pt", "nb", "lower"))
})

test_that("nb_exact_ci is reproducible given a fixed seed", {
  truth <- rbinom(300, 1, 0.3); prob <- plogis(-0.8 + 1.5 * truth + rnorm(300))
  pt <- c(0.05, 0.1, 0.2)
  set.seed(99); a <- nb_exact_ci(truth, prob, 0.05, pt, B = 299, cores = 1)
  set.seed(99); b <- nb_exact_ci(truth, prob, 0.05, pt, B = 299, cores = 1)
  expect_identical(a, b)
})

test_that("nb_exact_ci unstratified path runs and brackets the estimate", {
  set.seed(7)
  truth <- rbinom(400, 1, 0.3); prob <- plogis(-0.8 + 1.5 * truth + rnorm(400))
  pt <- c(0.05, 0.1, 0.2)
  ci <- nb_exact_ci(truth, prob, 0.05, pt, B = 299, side = "both",
                    stratified = FALSE, cores = 1)
  expect_equal(ci$nb, nb_exact(truth, prob, 0.05, pt))
  expect_true(all(ci$lower <= ci$nb + 1e-9))
  expect_true(all(ci$upper >= ci$nb - 1e-9))
})

test_that("nb_exact_ci band collapses onto the estimate when every unit is flagged", {
  # prob = 1 >= every pt < 1, so every stratified resample reproduces treat-all
  # exactly (TPR = FPR = 1 regardless of which indices are drawn): band has zero width.
  truth <- c(1, 0, 0, 1, 0, 0, 0, 1, 0, 0)
  pt <- c(0.02, 0.1, 0.25)
  set.seed(3)
  ci <- nb_exact_ci(truth, rep(1, length(truth)), 0.08, pt, B = 199,
                    side = "both", cores = 1)
  expect_equal(ci$lower, ci$nb)
  expect_equal(ci$upper, ci$nb)
  expect_equal(ci$nb, nb_treat_all(0.08, pt))
})

test_that("nb_exact_ci rejects an unknown side", {
  truth <- c(1, 0, 1, 0); prob <- c(0.9, 0.1, 0.8, 0.2)
  expect_error(nb_exact_ci(truth, prob, 0.1, 0.1, B = 9, side = "upper", cores = 1))
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

test_that("nb_binormal_band pi0 defaults to pi and its mu matches ap_scalar_to_prev", {
  pi0 <- 0.1; pi <- 0.03
  pt <- c(0.02, 0.05, 0.1)
  pr <- ap_binormal(mu = 1.4, pi0, grid = 3000)
  # omitting pi0 prices the PR-AUC at the target prevalence itself
  b_def <- nb_binormal_band(pr, pi, pt, spread = 0.02)
  b_pi  <- nb_binormal_band(pr, pi, pt, spread = 0.02, pi0 = pi)
  expect_equal(b_def, b_pi)
  # central mu is exactly the ap_scalar_to_prev reconstruction at pi0
  b <- nb_binormal_band(pr, pi, pt, spread = 0.02, pi0 = pi0)
  expect_equal(attr(b, "mu")[["central"]],
               ap_scalar_to_prev(pr, pi0, pi, grid = 3000)$mu, tolerance = 1e-6)
})

test_that("nb_binormal_band edges equal nb_binormal at the fitted mu", {
  pi0 <- 0.08; pi <- 0.04
  pt <- c(0.03, 0.07, 0.15)
  pr <- ap_binormal(mu = 1.6, pi0, grid = 3000)
  b <- nb_binormal_band(pr, pi, pt, spread = 0.025, pi0 = pi0, side = "both")
  mu <- attr(b, "mu")
  expect_equal(b$lower, nb_binormal(mu[["lower"]], pi, pt))
  expect_equal(b$upper, nb_binormal(mu[["upper"]], pi, pt))
  expect_equal(b$nb,    nb_binormal(mu[["central"]], pi, pt))
})

test_that("nb_binormal_band carries only central+lower mu when one-sided", {
  b <- nb_binormal_band(0.8, pi = 0.05, pt = c(0.05, 0.1), spread = 0.03,
                        pi0 = 0.1)
  expect_named(attr(b, "mu"), c("central", "lower"))
  expect_false("upper" %in% names(attr(b, "mu")))
})

test_that("nb_binormal_band accepts a scalar pt and rejects an unknown side", {
  b <- nb_binormal_band(0.8, pi = 0.05, pt = 0.1, spread = 0.03, pi0 = 0.1)
  expect_equal(nrow(b), 1L)
  expect_error(nb_binormal_band(0.8, 0.05, 0.1, spread = 0.03, side = "upper"))
})

test_that("the best-achievable curve dominates treat-all", {
  pi <- 0.1
  pt <- c(0.05, 0.1, 0.2, 0.3)
  expect_true(all(nb_binormal(mu = 1.5, pi, pt) >= nb_treat_all(pi, pt) - 1e-9))
})

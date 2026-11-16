test_that("ap_pointwise is NA without both classes and bounded in [0, 1]", {
  expect_true(is.na(ap_pointwise(rep(1, 5), runif(5), pi = 0.1)))
  expect_true(is.na(ap_pointwise(rep(0, 5), runif(5), pi = 0.1)))
  set.seed(30)
  truth <- rbinom(200, 1, 0.3)
  ap <- ap_pointwise(truth, runif(200), pi = 0.1)
  expect_true(ap >= 0 && ap <= 1)
})

test_that("a perfect ranking gives average precision 1 at any prevalence", {
  truth <- c(0, 0, 0, 1, 1)
  prob  <- c(1, 2, 3, 4, 5)              # the two presences score highest
  expect_equal(ap_pointwise(truth, prob, pi = 0.5),  1)
  expect_equal(ap_pointwise(truth, prob, pi = 0.01), 1)
})

test_that("ap_binormal equals the prevalence baseline with no discrimination", {
  # mu = 0 => precision is flat at pi => AP = pi (random classifier)
  expect_equal(ap_binormal(mu = 0, pi = 0.1), 0.1, tolerance = 1e-3)
  expect_equal(ap_binormal(mu = 0, pi = 0.4), 0.4, tolerance = 1e-3)
})

test_that("ap_binormal rises with separation and stays within (pi, 1)", {
  pi <- 0.1
  a0 <- ap_binormal(0.5, pi); a1 <- ap_binormal(1.5, pi); a2 <- ap_binormal(3, pi)
  expect_true(a0 < a1 && a1 < a2)
  expect_true(a2 > pi && a2 < 1)
})

test_that("ap_scalar_to_prev inverts ap_binormal and is self-consistent", {
  pr_auc <- 0.4; pi0 <- 0.1; pi_target <- 0.03
  res <- ap_scalar_to_prev(pr_auc, pi0, pi_target)
  expect_named(res, c("ap_target", "mu", "implied_roc_auc"))
  # the fitted mu reproduces the reported PR-AUC at the design prevalence
  expect_equal(ap_binormal(res$mu, pi0, grid = 20000), pr_auc, tolerance = 1e-4)
  # ap_target is just the same ROC re-integrated at the new prevalence
  expect_equal(res$ap_target, ap_binormal(res$mu, pi_target, grid = 20000))
  # implied ROC-AUC follows the binormal relation pnorm(mu / sqrt(2))
  expect_equal(res$implied_roc_auc, pnorm(res$mu / sqrt(2)))
})

test_that("ap_pointwise and ap_binormal agree on data drawn from the ROC", {
  # large binormal sample: the point-level estimator should track the
  # closed-form binormal AP once re-priced to the same prevalence.
  set.seed(31)
  mu <- 1.5; pi <- 0.1; n <- 2e5
  truth <- rbinom(n, 1, 0.5)                       # sample prevalence ~ 0.5
  prob  <- rnorm(n, mean = mu * truth, sd = 1)     # binormal scores
  expect_equal(ap_pointwise(truth, prob, pi),
               ap_binormal(mu, pi), tolerance = 0.02)
})

test_that("pr_curve_exact has the right shape and monotone recall", {
  set.seed(32)
  truth <- rbinom(150, 1, 0.3)
  prob  <- plogis(-0.5 + truth + rnorm(150))
  cv <- pr_curve_exact(truth, prob, pi = 0.1)
  expect_s3_class(cv, "data.frame")
  expect_named(cv, c("recall", "precision"))
  expect_equal(nrow(cv), length(truth))
  expect_false(is.unsorted(cv$recall))             # recall never decreases
  expect_true(all(is.finite(cv$precision)))
})

test_that("pr_curve_binormal returns a grid-length curve of valid precisions", {
  cv <- pr_curve_binormal(mu = 1.2, pi = 0.1, grid = 250)
  expect_named(cv, c("recall", "precision"))
  expect_equal(nrow(cv), 250)
  expect_true(all(cv$precision > 0 & cv$precision < 1))
  expect_true(all(cv$recall > 0 & cv$recall < 1))
})

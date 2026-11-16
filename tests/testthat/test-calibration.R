test_that("clamp bounds probabilities and leaves interior values untouched", {
  expect_equal(clamp(c(0, 1), eps = 1e-6), c(1e-6, 1 - 1e-6))
  p <- c(0.2, 0.5, 0.8)
  expect_equal(clamp(p), p)
  expect_true(all(clamp(c(-5, 5)) >= 1e-6 & clamp(c(-5, 5)) <= 1 - 1e-6))
})

test_that("cox_calibration returns the documented, named pair", {
  set.seed(20)
  truth <- rbinom(200, 1, 0.3)
  prob  <- plogis(rnorm(200))
  cc <- cox_calibration(truth, prob)
  expect_named(cc, c("cox_intercept", "cox_slope"))
  expect_length(cc, 2)
})

test_that("a perfectly calibrated large sample recovers slope 1, intercept 0", {
  set.seed(21)
  n  <- 20000
  lp <- rnorm(n, 0, 1.5)             # true linear predictor
  prob  <- plogis(lp)
  truth <- rbinom(n, 1, prob)        # outcomes drawn from those same probs
  cc <- cox_calibration(truth, prob)
  expect_equal(unname(cc["cox_slope"]),     1, tolerance = 0.1)
  expect_equal(unname(cc["cox_intercept"]), 0, tolerance = 0.1)
})

test_that("separated fits are dropped to NA rather than returning huge coefs", {
  # a cleanly separating predictor on the usual scale makes the slope diverge
  # (|coef| >= 15), which the guard should turn into NA instead of a huge number.
  truth <- c(0, 0, 0, 1, 1, 1)
  prob  <- c(0.1, 0.2, 0.3, 0.7, 0.8, 0.9)
  cc <- suppressWarnings(cox_calibration(truth, prob))
  expect_true(is.na(cc["cox_slope"]))
})

test_that("recalibration is the identity when observed prevalence is the target", {
  prob <- c(0.1, 0.3, 0.5, 0.7, 0.9)
  expect_equal(recalibrate_to_prevalence(prob, p_obs = 0.4, pi = 0.4), prob,
               tolerance = 1e-6)
})

test_that("recalibration preserves ordering and moves with the target", {
  prob <- c(0.1, 0.3, 0.5, 0.7, 0.9)
  down <- recalibrate_to_prevalence(prob, p_obs = 0.4, pi = 0.05)
  up   <- recalibrate_to_prevalence(prob, p_obs = 0.4, pi = 0.60)
  expect_equal(order(down), order(prob))   # rank order intact
  expect_true(all(down < prob))            # lower target prevalence lowers probs
  expect_true(all(up   > prob))            # higher target raises them
})

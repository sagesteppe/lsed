test_that("perfect, reversed, and uninformative rankings hit 1, 0, 0.5", {
  truth <- c(0, 0, 1, 1)
  expect_equal(roc_auc(truth, prob = c(1, 2, 3, 4)), 1)   # presences outscore
  expect_equal(roc_auc(truth, prob = c(4, 3, 2, 1)), 0)   # absences outscore
  expect_equal(roc_auc(truth, prob = c(1, 1, 1, 1)), 0.5) # all tied
})

test_that("a missing class returns NA", {
  expect_true(is.na(roc_auc(rep(1, 5), prob = runif(5))))
  expect_true(is.na(roc_auc(rep(0, 5), prob = runif(5))))
})

test_that("the rank identity equals the brute-force concordance", {
  # AUC = P(score of a random presence > score of a random absence),
  # ties counting as 1/2. Compare the Mann-Whitney form to the O(n^2) count.
  set.seed(1)
  truth <- rbinom(60, 1, 0.4)
  prob  <- runif(60)
  pos <- prob[truth == 1]; neg <- prob[truth == 0]
  conc <- outer(pos, neg, function(a, b) (a > b) + 0.5 * (a == b))
  expect_equal(roc_auc(truth, prob), mean(conc))
})

test_that("AUC is invariant to a monotonic transform of the scores", {
  set.seed(2)
  truth <- rbinom(50, 1, 0.5)
  prob  <- runif(50)
  expect_equal(roc_auc(truth, prob), roc_auc(truth, qlogis(prob)))
})

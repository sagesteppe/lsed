test_that("resolve_cores defaults to the mc.cores option when NULL", {
  withr::with_options(list(mc.cores = 3L), {
    # not on Windows and no _R_CHECK_LIMIT_CORES_ cap
    skip_on_os("windows")
    withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "")
    expect_equal(resolve_cores(NULL, cap = 8), 3L)
  })
})

test_that("resolve_cores caps at the job count and floors at 1", {
  skip_on_os("windows")
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "")
  expect_equal(resolve_cores(16, cap = 4), 4L)   # capped at jobs
  expect_equal(resolve_cores(0, cap = 4), 1L)    # floored at 1
  expect_equal(resolve_cores(-5, cap = 4), 1L)
})

test_that("resolve_cores honours _R_CHECK_LIMIT_CORES_", {
  skip_on_os("windows")
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_equal(resolve_cores(8, cap = 8), 2L)    # check env caps usable cores at 2
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "false")
  expect_equal(resolve_cores(8, cap = 8), 8L)    # "false" lifts the cap
})

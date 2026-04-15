test_that("inject_patch can overwrite a locked environment binding", {
  env <- new.env()
  env$broken_child <- function() { "I am broken" }
  env$parent_caller <- function() { env$broken_child() }
  lockEnvironment(env)
  lockBinding("broken_child", env)
  lockBinding("parent_caller", env)

  expect_equal(env$parent_caller(), "I am broken")

  fixed_child <- function() { "I am FIXED" }
  inject_patch(env, patch_list = list(broken_child = fixed_child))

  expect_equal(env$parent_caller(), "I am FIXED")
})

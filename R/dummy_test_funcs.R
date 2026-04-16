# R/dummy_test_funcs.R

#' A dummy parent function to test namespace injection
dummy_parent_func <- function(x) {
  # This calls the internal, hidden child function
  child_result <- dummy_child_func(x)
  return(paste("Parent output ->", child_result))
}

#' A dummy child function that we will "hotfix" in tests
dummy_child_func <- function(x) {
  return(paste("I am the BROKEN child. Input:", x))
}
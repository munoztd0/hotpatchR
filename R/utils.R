# R/dummy_test_funcs.R

#' A dummy parent function to test namespace injection
#'
#' @param x Input value to pass to child function
#'
#' @return A character string with parent output
#'
#' @export
dummy_parent_func <- function(x) {
  # This calls the internal, hidden child function
  child_result <- dummy_child_func(x)
  return(paste("Parent output ->", child_result))
}

#' A dummy child function that we will "hotfix" in tests
#'
#' @param x Input value
#'
#' @return A character string with child output
#'
#' @keywords internal
dummy_child_func <- function(x) {
  return(paste("I am the BROKEN child. Input:", x))
}
# tests/testthat/test-injection.R

test_that("inject_patch successfully rewrites internal namespace routing", {
  
  # 1. Verify the baseline (broken) state
  baseline <- dummy_parent_func("test")
  expect_equal(baseline, "Parent output -> I am the BROKEN child. Input: test")
  
  # 2. Define the surgical fix
  my_fixed_child <- function(x) {
    return(paste("I am the FIXED child! Input:", x))
  }
  
  # 3. Inject the patch into the package's own namespace
  inject_patch(
    pkg = "hotpatchR", 
    patch_list = list(dummy_child_func = my_fixed_child)
  )
  
  # 4. Verify the parent function now automatically uses the fixed child
  patched_result <- dummy_parent_func("test")
  expect_equal(patched_result, "Parent output -> I am the FIXED child! Input: test")
  
  # 5. Clean up: Revert the patch using the backup store
  undo_patch(pkg = "hotpatchR", names = "dummy_child_func")
  
  # 6. Verify the environment is restored to its original state
  restored_result <- dummy_parent_func("test")
  expect_equal(restored_result, "Parent output -> I am the BROKEN child. Input: test")
  
})

# Junco Hotfix Infrastructure: The `hotpatchR` Project

## 1. Context & The Core Problem
The `junco` package requires surgical hotfixes to legacy versions (e.g., v0.1.1, v0.1.2) deployed in locked containers. Because we cannot natively rebuild and deploy these legacy packages, hotfixes must be dynamically injected into the R environment at runtime.

**The Namespace Trap:**
When a hotfix is sourced into the R Global Environment, internal package functions ignore it. If `tt_to_tlgrtf()` calls `a_freq_j()`, and we fix `a_freq_j()` globally, the package continues to use its own broken, internal version of `a_freq_j()`. 

**The Current Workaround (Painful):**
Developers must use dependency mappers (`pkgnet`) to find every single parent function that relies on the broken function, extract them all, and dump them into a massive `.R` script. Furthermore, automated CI pipelines (via `testthat`) actively isolate test environments, requiring "nuclear" workarounds like physical file splicing (`cat hotfix.R >> R/zzz.R`) to validate fixes.

---

## 2. The Solution: `hotpatchR`
We need an internal utility package (`hotpatchR`) designed to safely and dynamically rewrite a locked R package namespace in memory. 

Instead of pulling package functions out into the Global Environment, `hotpatchR` injects the developer's fix *into* the locked package namespace.

### Proposed Core API:
* `hotpatchR::inject_patch(pkg = "junco", patch_list = list(a_freq_j = my_fixed_func))`
    * *Action:* Unlocks the `junco` namespace, overwrites the function pointer for `a_freq_j`, updates the function's parent environment to match the namespace, and re-locks it.
* `hotpatchR::test_patched_dir(pkg = "junco", test_path = "tests/testthat")`
    * *Action:* A wrapper around `testthat::test_dir` that disables strict snapshot tear-downs and forces the tests to execute against the newly mutated namespace in memory.

---

## 3. Go-Forward Plan
To build this, the next AI session (or developer) needs to follow this sequence:

**Phase 1: Memory Hacking (Core Logic)**
1. Write the `inject_patch` function utilizing `unlockBinding()`, `assignInNamespace()`, and `environment() <-`.
2. Ensure the injected function inherits the package's internal namespace so it can call other unexported functions.

**Phase 2: CI & Testing Integration**
1. Write the `test_patched_dir` wrapper to execute tests against the mutated memory state without `testthat` resetting the environment.
2. Implement an `undo_patch()` function to revert the namespace to its original state if needed.

**Phase 3: The CLI / Scripting Wrapper**
1. Create a standard template script that users can run in their legacy containers: `hotpatchR::apply_hotfix_file("dev/junco_hotfix_v0-1-1.R")`.

---

## 4. The Benchmark Test (Proof of Concept)
Do not proceed to Phase 2 until this exact R script executes successfully. This is the ultimate test of the package.

```r
# --- 1. Setup a dummy environment ---
# Simulate a locked package named 'dummyPkg'
env <- new.env()
env$broken_child <- function() { return("I am broken") }
env$parent_caller <- function() { return(env$broken_child()) }

# Lock it down like a real package
lockEnvironment(env)
lockBinding("broken_child", env)
lockBinding("parent_caller", env)

# Verify the baseline state
stopifnot(env$parent_caller() == "I am broken")

# --- 2. The Developer's Fix ---
fixed_child <- function() { return("I am FIXED") }

# --- 3. The hotpatchR Execution ---
# (Logic to be implemented inside hotpatchR::inject)
unlockBinding("broken_child", env)
assign("broken_child", fixed_child, envir = env)
lockBinding("broken_child", env)

# --- 4. THE VALIDATION ---
# If the parent_caller returns "I am FIXED", the namespace hack is successful.
result <- env$parent_caller()

if (result == "I am FIXED") {
  message("SUCCESS: hotpatchR has successfully hijacked the namespace.")
} else {
  stop("FAILURE: The parent function ignored the injected patch.")
}

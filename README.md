# hotpatchR

<p align="left"><a href="inst/hex/hotpatchR-hex.svg"><img src="inst/hex/hotpatchR-hex.svg" alt="hotpatchR hex logo" width="120"/></a></p>

[![R-CMD check](https://github.com/munoztd0/hotpatchR/actions/workflows/r-cmd-check.yaml/badge.svg)](https://github.com/munoztd0/hotpatchR/actions/workflows/r-cmd-check.yaml)
[![pkgdown](https://github.com/munoztd0/hotpatchR/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/munoztd0/hotpatchR/actions/workflows/pkgdown.yaml)

`hotpatchR` is a runtime hotfix utility for locked R package namespaces.
It is built for legacy container workflows where a package version is sealed in place
and cannot be rebuilt or redeployed.

## Continuous integration

This repository includes GitHub Actions workflows in `.github/workflows`:

- `r-cmd-check.yaml` — runs `R CMD check` on push and pull requests
- `pkgdown.yaml` — builds the pkgdown site and uploads generated docs as an artifact

These workflows are designed to catch package issues early and keep documentation up to date.

## The core problem

When R loads a package, it builds a locked namespace.
Internal package functions call each other inside that namespace, and the namespace acts
as a protective bubble.

That means:

- a broken internal function like `a_freq_j()` is only visible inside the package namespace
- a package function like `tt_to_tlgrtf()` resolves internal calls from that same locked namespace
- sourcing a fixed `a_freq_j()` into the global environment does not update the package's internal pointer

In practice, this forces a painful current workflow:

- identify the broken function
- find every package child function that depends on it
- copy the broken function plus all dependent callers into a hotfix script
- source the hotfix script into the global environment
- run tests while fighting CI and namespace isolation

This is manual, brittle, and scales badly for large legacy packages.

## What hotpatchR solves

`hotpatchR` changes the problem from "global environment hacking" to "namespace surgery." 
Instead of copying dependencies into the global environment, it overwrites the function
inside the package namespace itself.

Benefits:

- surgical patching of exactly the broken functions
- internal callers automatically see the fix
- no need to copy parent callers or entire dependency chains
- easier validation in live test workflows

## Core API

- `inject_patch(pkg, patch_list)`: overwrite functions inside a package namespace or environment
- `undo_patch(pkg, names = NULL)`: restore backed-up originals for patched bindings
- `test_patched_dir(pkg, test_path)`: run `testthat` tests against the modified namespace
- `apply_hotfix_file(file, pkg = NULL)`: load a hotfix script and inject the included patch list

## Example usage

```r
library(hotpatchR)

pkg_env <- new.env()
pkg_env$broken_child <- function() "I am broken"
pkg_env$parent_caller <- function() pkg_env$broken_child()
lockEnvironment(pkg_env)
lockBinding("broken_child", pkg_env)
lockBinding("parent_caller", pkg_env)

inject_patch(pkg_env, list(broken_child = function() "I am FIXED"))

pkg_env$parent_caller()
#> "I am FIXED"
```

## How it works

`inject_patch()` unlocks the binding inside the target namespace, assigns the replacement function,
and then re-locks the binding. This keeps the change local to the package namespace and preserves
normal internal function resolution.

## Vignettes and docs

See `vignettes/hotpatchR-intro.Rmd` for a deeper explanation of the namespace trap,
rollback workflows, and example hotfix scripts.

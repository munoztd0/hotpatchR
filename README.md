# hotpatchR <a href='https://github.com/munoztd0/hotpatchR'><img src="inst/hex/logo.png." align="right" width="200"/></a>

<!-- start badges -->
[![R-CMD-check](https://github.com/munoztd0/hotpatchR/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/munoztd0/hotpatchR/actions/workflows/R-CMD-check.yaml)
[![pkgdown](https://github.com/munoztd0/hotpatchR/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/munoztd0/hotpatchR/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

![GitHub forks](https://img.shields.io/github/forks/munoztd0/hotpatchR?style=social)
![GitHub repo stars](https://img.shields.io/github/stars/munoztd0/hotpatchR?style=social)

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/munoztd0/hotpatchR)
![GitHub contributors](https://img.shields.io/github/contributors/munoztd0/hotpatchR)
![GitHub last commit](https://img.shields.io/github/last-commit/munoztd0/hotpatchR)
![GitHub pull requests](https://img.shields.io/github/issues-pr/munoztd0/hotpatchR)
![GitHub repo size](https://img.shields.io/github/repo-size/munoztd0/hotpatchR)
[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Current Version](https://img.shields.io/github/r-package/v/munoztd0/hotpatchR/main?color=purple&label=package%20version)](https://github.com/munoztd0/hotpatchR/tree/main)
[![Open Issues](https://img.shields.io/github/issues-raw/munoztd0/hotpatchR?color=red&label=open%20issues)](https://github.com/munoztd0/hotpatchR/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc)
<!-- end badges -->



<!-- badges: start -->


`hotpatchR` is a runtime hotfix utility for locked R package namespaces.
It is built for legacy container workflows where a package version is sealed in place
and cannot be rebuilt or redeployed.

## The core problem

When R loads a package, it builds a locked namespace.
Internal package functions call each other inside that namespace, and the namespace acts
as a protective bubble.

That means:

- a broken internal function like `broken_fun()` is only visible inside the package namespace
- a package function like `caller_fun()` resolves internal calls from that same locked namespace
- sourcing a fixed `broken_fun()` into the global environment does not update the package's internal pointer

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

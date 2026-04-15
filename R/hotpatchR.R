#' Inject a runtime patch into a locked package namespace
#'
#' @param pkg A package name as a string.
#' @param patch_list A named list of functions to overwrite in the package namespace.
#' @param lock Whether to re-lock bindings after patching.
#' @return Invisibly TRUE on success.
#' @export
inject_patch <- function(pkg, patch_list, lock = TRUE) {
  stopifnot(is.list(patch_list), length(patch_list) > 0)

  ns <- if (is.environment(pkg)) {
    pkg
  } else {
    stopifnot(is.character(pkg), length(pkg) == 1)
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(sprintf("Package '%s' must be installed and loadable.", pkg), call. = FALSE)
    }
    getNamespace(pkg)
  }

  if (!is.environment(ns)) {
    stop("pkg must be a package name or an environment.", call. = FALSE)
  }

  patch_keys <- names(patch_list)
  if (is.null(patch_keys) || any(patch_keys == "")) {
    stop("patch_list must be a named list of functions.", call. = FALSE)
  }

  for (name in patch_keys) {
    replacement <- patch_list[[name]]
    if (!is.function(replacement)) {
      stop(sprintf("Replacement for '%s' must be a function.", name), call. = FALSE)
    }

    if (!exists(name, envir = ns, inherits = FALSE)) {
      stop(sprintf("Object '%s' not found in the target environment.", name), call. = FALSE)
    }

    environment(replacement) <- ns
    if (bindingIsLocked(name, ns)) {
      .hotpatchR_unlock_binding(name, ns)
    }

    assign(name, replacement, envir = ns)
    .hotpatchR_backup_store(pkg, name)

    if (lock) {
      .hotpatchR_lock_binding(name, ns)
    }
  }

  invisible(TRUE)
}

.hotpatchR_env <- new.env(parent = emptyenv())

.hotpatchR_unlock_binding <- function(name, env) {
  fn <- get("unlockBinding", envir = baseenv())
  fn(name, env)
}

.hotpatchR_lock_binding <- function(name, env) {
  fn <- get("lockBinding", envir = baseenv())
  fn(name, env)
}

.hotpatchR_backup_store <- function(pkg, name) {
  pkg_key <- if (is.environment(pkg)) {
    paste0("env:", format(pkg))
  } else {
    pkg
  }

  key <- paste(pkg_key, name, sep = "::")
  ns <- if (is.environment(pkg)) pkg else getNamespace(pkg)
  if (!exists(key, envir = .hotpatchR_env, inherits = FALSE)) {
    original <- get(name, envir = ns)
    assign(key, original, envir = .hotpatchR_env)
  }
}

#' Undo a previously injected patch
#'
#' @param pkg Package name or environment.
#' @param names Character vector of patched object names to restore. If NULL, restore all stored backups for pkg.
#' @return Invisibly TRUE on success.
#' @export
undo_patch <- function(pkg, names = NULL) {
  ns <- if (is.environment(pkg)) {
    pkg
  } else {
    stopifnot(is.character(pkg), length(pkg) == 1)
    getNamespace(pkg)
  }

  keys <- ls(envir = .hotpatchR_env)
  prefix <- if (is.environment(pkg)) {
    paste0("env:", format(pkg), "::")
  } else {
    paste0("^", pkg, "::")
  }
  pkg_keys <- grep(prefix, keys, value = TRUE, fixed = is.environment(pkg))
  if (length(pkg_keys) == 0L) {
    msg_target <- if (is.environment(pkg)) "environment" else sprintf("package '%s'", pkg)
    warning(sprintf("No patch backup found for %s.", msg_target), call. = FALSE)
    return(invisible(FALSE))
  }

  if (!is.null(names)) {
    filter_keys <- paste0(if (is.environment(pkg)) prefix else gsub("\\^", "", prefix), names)
    pkg_keys <- pkg_keys[pkg_keys %in% filter_keys]
  }

  for (key in pkg_keys) {
    original <- get(key, envir = .hotpatchR_env)
    name <- sub(prefix, "", key, fixed = is.environment(pkg))
    if (bindingIsLocked(name, ns)) {
      .hotpatchR_unlock_binding(name, ns)
    }
    assign(name, original, envir = ns)
    .hotpatchR_lock_binding(name, ns)
    rm(list = key, envir = .hotpatchR_env)
  }

  invisible(TRUE)
}

#' Run testthat tests against a patched package namespace
#'
#' @param pkg Package name that has been patched in memory.
#' @param test_path Path to tests to run.
#' @param reporter testthat reporter name or object.
#' @return Result object from testthat::test_dir.
#' @export
test_patched_dir <- function(pkg, test_path = "tests/testthat", reporter = "summary") {
  if (!requireNamespace("testthat", quietly = TRUE)) {
    stop("testthat must be installed to run patched tests.", call. = FALSE)
  }

  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(sprintf("Package '%s' must be installed and loadable.", pkg), call. = FALSE)
  }

  if (!dir.exists(test_path)) {
    stop(sprintf("Test path '%s' does not exist.", test_path), call. = FALSE)
  }

  getNamespace(pkg)
  testthat::test_dir(test_path, reporter = reporter)
}

#' Apply a hotfix file and inject the patch definitions
#'
#' @param file Path to an R script that defines `patch_list` and optionally `pkg`.
#' @param pkg Optional package name if not provided in the script.
#' @return Invisibly TRUE on success.
#' @export
apply_hotfix_file <- function(file, pkg = NULL) {
  if (!file.exists(file)) {
    stop(sprintf("Hotfix file '%s' not found.", file), call. = FALSE)
  }

  env <- new.env(parent = baseenv())
  sys.source(file, envir = env)

  if (is.null(pkg)) {
    if (!exists("pkg", envir = env, inherits = FALSE)) {
      stop("Package name must be provided via pkg argument or in the hotfix file.", call. = FALSE)
    }
    pkg <- get("pkg", envir = env)
  }

  if (!exists("patch_list", envir = env, inherits = FALSE)) {
    stop("Hotfix file must define a named list called patch_list.", call. = FALSE)
  }

  patch_list <- get("patch_list", envir = env)
  inject_patch(pkg = pkg, patch_list = patch_list)
  invisible(TRUE)
}

#' Compile C++ code
#'
#' [cpp_source()] compiles and loads a single C++ file for use in R.
#' [cpp_function()] compiles and loads a single function for use in R.
#' [cpp_eval()] evaluates a single C++ expression and returns the result.
#'
#' Within C++ code you can use `[[cpp11::linking_to("pkgxyz")]]` to link to
#' external packages. This is equivalent to putting those packages in the
#' `LinkingTo` field in a package DESCRIPTION.
#'
#' @param file A file containing C++ code to compile
#' @param code If non-null, the C++ code to compile
#' @param env The R environment where the R wrapping functions should be defined.
#' @param clean If `TRUE`, cleanup the files after sourcing
#' @param quiet If 'TRUE`, do not show compiler output
#' @param cxx_std The C++ standard to use, the `CXX_STD` make macro is set to
#'   this value. The default value queries the `CXX_STD` environment variable, or
#'   uses 'CXX11' if unset.
#' @param dir The directory to store the generated source files. `tempfile()` is
#'   used by default. The directory will be removed if `clean` is `TRUE`.
#' @return For [cpp_source()] and `[cpp_function()]` the results of
#'   [dyn.load()] (invisibly). For `[cpp_eval()]` the results of the evaluated
#'   expression.
#' @examples
#' \dontrun{
#' cpp_source(
#'   code = '#include "cpp11/integers.hpp"
#'
#'   [[cpp11::register]]
#'   int num_odd(cpp11::integers x) {
#'     int total = 0;
#'     for (int val : x) {
#'       if ((val % 2) == 1) {
#'         ++total;
#'       }
#'     }
#'     return total;
#'   }
#'   ')
#'
#' num_odd(as.integer(c(1:10, 15, 23)))
#'
#' if (require("progress")) {
#'
#' cpp_source(
#'   code = '
#' #include <cpp11/R.hpp>
#' #include <RProgress.h>
#'
#' [[cpp11::linking_to("progress")]]
#'
#' [[cpp11::register]] void
#' show_progress() {
#'   RProgress::RProgress pb("Downloading [:bar] ETA: :eta");
#'
#'   pb.tick(0);
#'   for (int i = 0; i < 100; i++) {
#'     usleep(2.0 / 100 * 1000000);
#'     pb.tick();
#'   }
#' }
#' ')
#'
#' show_progress()
#' }
#' }
#' @export
cpp_source <- function(file, code = NULL, env = parent.frame(), clean = TRUE, quiet = TRUE, cxx_std = Sys.getenv("CXX_STD", "CXX11"), dir = tempfile()) {
  stop_unless_installed(c("brio", "callr", "cli", "decor", "desc", "glue", "tibble", "vctrs"))

  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(file.path(dir, "R"), showWarnings = FALSE)
  dir.create(file.path(dir, "src"), showWarnings = FALSE)

  if (!is.null(code)) {
    tf <- tempfile(pattern = "code_", fileext = ".cpp")
    file <- tf
    if (isTRUE(clean)) {
      on.exit(unlink(tf))
    }
    brio::write_lines(code, file)
  }
  if (!any(tools::file_ext(file) %in% c("cpp", "cc"))) {
    stop("`file` must have a `.cpp` or `.cc` extension")
  }

  base_cpp <- (basename(file) %in% "cpp11.cpp")

  if (base_cpp) {
    name <- set_cpp_name(file)
    package <- tools::file_path_sans_ext(name)
  }
  else {
    # name and package might be different if cpp_source was called multiple times
    name <- basename(file)
    package <- tools::file_path_sans_ext(generate_cpp_name(file))
  }

  # file not points to another location
  file.copy(file, file.path(dir, "src", name))
  #change variable name to reflect this
  file <- file.path(dir, "src", name)


  suppressWarnings(
    all_decorations <- decor::cpp_decorations(dir, is_attribute = TRUE)
  )

  check_valid_attributes(all_decorations)

  cli_suppress(
    funs <- get_registered_functions(all_decorations, "cpp11::register")
  )
  cpp_functions_definitions <- generate_cpp_functions(funs, package = package)

  cpp_path <- file.path(dirname(file), "cpp11.cpp")
  brio::write_lines(c('#include "cpp11/declarations.hpp"', "using namespace cpp11;", cpp_functions_definitions), cpp_path)

  linking_to <- union(get_linking_to(all_decorations), "cpp11")

  includes <- generate_include_paths(linking_to)

  if (isTRUE(clean)) {
    on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  }

  r_functions <- generate_r_functions(funs, package = package, use_package = TRUE)

  makevars_content <- generate_makevars(includes, cxx_std)

  brio::write_lines(makevars_content, file.path(dir, "src", "Makevars"))

  source_files <- normalizePath(c(file, cpp_path), winslash = "/")
  res <- callr::rcmd("SHLIB", source_files, user_profile = TRUE, show = !quiet, wd = file.path(dir, "src"))
  if (res$status != 0) {
    cat(res$stderr)
    stop("Compilation failed.", call. = FALSE)
  }


  shared_lib <- file.path(dir, "src", paste0(tools::file_path_sans_ext(basename(file)), .Platform$dynlib.ext))
  r_path <- file.path(dir, "R", "cpp11.R")
  brio::write_lines(r_functions, r_path)
  source(r_path, local = env)

  dyn.load(shared_lib, local = TRUE, now = TRUE)
}

the <- new.env(parent = emptyenv())
the$count <- 0L

set_cpp_name <- function(name) {
  ext <- tools::file_ext(name)
  root <- tools::file_path_sans_ext(basename(name))
  count <- 2
  new_name <- sprintf("%s_%i", root, count)
  sprintf("%s.%s", new_name, ext)
}

generate_cpp_name <- function(name, loaded_dlls = c("cpp11", names(getLoadedDLLs()))) {
  ext <- tools::file_ext(name)
  root <- tools::file_path_sans_ext(basename(name))
  count <- 2
  new_name <- root
  while(new_name %in% loaded_dlls) {
    new_name <- sprintf("%s_%i", root, count)
    count <- count + 1
  }
  sprintf("%s.%s", new_name, ext)
}



generate_include_paths <- function(packages) {
  out <- character(length(packages))
  for (i in seq_along(packages)) {
    path <- system.file(package = packages[[i]], "include")
    if (is_windows()) {
      path <- utils::shortPathName(path)
    }
    out[[i]] <- paste0("-I", shQuote(path))
  }
  out
}

generate_makevars <- function(includes, cxx_std) {
  c(sprintf("CXX_STD=%s", cxx_std), sprintf("PKG_CPPFLAGS=%s", paste0(includes, collapse = " ")))
}

#' @rdname cpp_source
#' @export
cpp_function <- function(code, env = parent.frame(), clean = TRUE, quiet = TRUE, cxx_std = Sys.getenv("CXX_STD", "CXX11")) {
  cpp_source(code = paste(c('#include "cpp11.hpp"',
        "using namespace cpp11;",
        "namespace writable = cpp11::writable;",
        "[[cpp11::register]]",
        code),
      collapse = "\n"),
    env = env,
    clean = clean,
    quiet = quiet,
    cxx_std = cxx_std
  )
}

utils::globalVariables("f")

#' @rdname cpp_source
#' @export
cpp_eval <- function(code, env = parent.frame(), clean = TRUE, quiet = TRUE, cxx_std = Sys.getenv("CXX_STD", "CXX11")) {
  cpp_source(code = paste(c('#include "cpp11.hpp"',
        "using namespace cpp11;",
        "namespace writable = cpp11::writable;",
        "[[cpp11::register]]",
        "SEXP f() { return as_sexp(",
        code,
        ");",
        "}"),
      collapse = "\n"),
    env = env,
    clean = clean,
    quiet = quiet,
    cxx_std = cxx_std
  )
  f()
}

get_linking_to <- function(decorations) {
  out <- decorations[decorations$decoration == "cpp11::linking_to", ]

  if (NROW(decorations) == 0) {
    return(character())
  }

  gsub("\"", "", as.character(unlist(out$params)))
}

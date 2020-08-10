# cpp11

<!-- badges: start -->
[![R build status](https://github.com/r-lib/cpp11/workflows/R-CMD-check/badge.svg)](https://github.com/r-lib/cpp11/actions)
[![codecov](https://codecov.io/gh/r-lib/cpp11/branch/master/graph/badge.svg?token=EEWYoCYxQ2)](https://codecov.io/gh/r-lib/cpp11)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN status](https://www.r-pkg.org/badges/version/cpp11)](https://CRAN.R-project.org/package=cpp11)
<!-- badges: end -->

cpp11 is a header-only R package that helps R package developers handle R objects with C++ code.
Its goals and syntax are similar to the excellent [Rcpp](https://cran.r-project.org/package=Rcpp) package.

## Using cpp11 in a package

To add cpp11 to an existing package, put your C++ files in the `src/` directory and add the following to your DESCRIPTION file:

```
LinkingTo: cpp11
SystemRequirements: C++11
```

Then decorate C++ functions you want to expose to R with `[[cpp11::register]]`. 
*Note that this is a [C++11 attribute](https://en.cppreference.com/w/cpp/language/attributes), not a comment like is used in Rcpp.*

cpp11 has no hard dependencies and does not use a shared library, so it is straightforward and reliable to use in packages.

Alternatively, you can [vendor](https://cpp11.r-lib.org/articles/motivations.html#vendoring) the current installed version of cpp11 headers into your package with `cpp11::vendor_cpp11()`.
This ensures the headers will remain unchanged until you explicitly update them.

## Getting started

See [vignette("cpp11")](https://cpp11.r-lib.org/articles/cpp11.html) to get started using cpp11 in your scripts, particularly if you are new to C++ programming.

## Motivations

[Rcpp](https://cran.r-project.org/package=Rcpp) has been a widely successful project, however over the years a number of issues and additional C++ features have arisen.
Adding these features to Rcpp would require a great deal work, or in some cases would be impossible without severely breaking backwards compatibility.

**cpp11** is a ground up rewrite of C++ bindings to R with different design trade-offs and features.

Changes that motivated cpp11 include:

- Enforcing [copy-on-write semantics](https://cpp11.r-lib.org/articles/motivations.html#copy-on-write-semantics).
- Improving the [safety](https://cpp11.r-lib.org/articles/motivations.html#improve-safety) of using the R API from C++ code.
- Supporting [ALTREP objects](https://cpp11.r-lib.org/articles/motivations.html#altrep-support).
- Using [UTF-8 strings](https://cpp11.r-lib.org/articles/motivations.html#utf-8-everywhere) everywhere.
- Applying newer [C++11 features](https://cpp11.r-lib.org/articles/motivations.html#c11-features).
- Having a more straightforward, [simpler implementation](https://cpp11.r-lib.org/articles/motivations.html#simpler-implementation).
- Faster [compilation time](https://cpp11.r-lib.org/articles/motivations.html#compilation-speed) with lower memory requirements.
- Being *completely* [header only](https://cpp11.r-lib.org/articles/motivations.html#header-only) to avoid ABI issues.
- Capable of [vendoring](https://cpp11.r-lib.org/articles/motivations.html#vendoring) if desired.
- More robust [protection](https://cpp11.r-lib.org/articles/motivations.html#protection) using a much more efficient linked list data structure.
- [Growing vectors](https://cpp11.r-lib.org/articles/motivations.html#growing-vectors) more efficiently.

See [vignette("motivations")](https://cpp11.r-lib.org/articles/motivations.html) for full details on the motivations for writing cpp11.

## Conversion from Rcpp

See [vignette("converting")](https://cpp11.r-lib.org/articles/converting.html) if you are already familiar with Rcpp or have an existing package that uses Rcpp and want to convert it to use cpp11.

## Internals

See [vignette("internals")](https://cpp11.r-lib.org/articles/internals.html) for details on the cpp11 implementation or if you would like to contribute to cpp11.

## Code of Conduct

Please note that the cpp11 project is released with a [Contributor Code of Conduct](https://cpp11.r-lib.org/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

## Thanks

cpp11 would not exist without Rcpp.
Thanks to the Rcpp authors, Dirk Eddelbuettel, Romain Francois, JJ Allaire, Kevin Ushey, Qiang Kou, Nathan Russell, Douglas Bates and John Chambers for their work writing and maintaining Rcpp.

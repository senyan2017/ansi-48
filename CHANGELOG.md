Changelog
=========


Unreleased
----------

* Added style presets / profiles. Bundle several styles under one name and use it from the command line (`--preset=NAME`, also `--profile` / `--style`) or as a library (`ansi::preset NAME`). Built-in presets: `error`, `headline`, `info`, `success`, `warning`. Add or override one by defining an `ansi::preset::NAME` function. List them with `--list-presets`.
* Added the `examples/presets` demonstration.


2.0.1 - 2019-02-04
------------------

* Bugfix in documentation.
* Fix undefined variable error when using `set -u`.


2.0.0 - 2018-08-25
------------------

* Released as an `bpm` module, but still can be executed as a simple command.
* Can be sourced and exposes functions.
* Include fixes for color tables.


1.1.0 - 2018-06-22
------------------

* Added `--bell` option.
* Namespaced function names so it would not conflict with other modules.
* ANSI detection in the terminal.
* Switched from `echo` to `printf`.


1.0.0 - 2016-09-21
------------------

* First tagged release.

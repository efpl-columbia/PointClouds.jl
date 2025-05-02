# Development

Development is done in the `dev` branch, in feature branches, or in personal forks of the repository.
Changes can only be merged into `main` if the CI tests are passing and the Git history is linear.

## Style Guide

- Source files are automatically formatted with [JuliaFormatter](https://github.com/domluna/JuliaFormatter.jl/) using the [configuration file](https://github.com/efpl-columbia/PointClouds.jl/blob/main/.JuliaFormatter.toml) that is included in the repository.
- The Git history is kept linear (rebasing instead of merging) and unrelated changes should be in separate commits.
  For the commit messages, a short, capitalized message using imperative mood is preferred (see [this article](https://cbea.ms/git-commit/)).

## Helper Commands

To simplify common development tasks, the repository includes recipes for the [`just` command runner](https://github.com/casey/just).
If you have `just` installed, you can run it without arguments in the repository directory to list the available recipes, and then `just RECIPE` to run one of the recipes.

Some useful recipes:

- `just repl`: Start a Julia REPL with the PointClouds package already imported.
- `just test`: Run all the tests, or only the tests from a specific file with e.g. `just test io` for `test/io_test.jl`.
- `just format`: Run JuliaFormatter for all the files in the `src` and `test` directories.
- `just servedocs [--skip-tests]`: Run the documentation website locally with live updates; `--skip-tests` disables doctests for faster iteration.
- `just benchmark <file>...`: Measure the performance of a few critical operations for one or several LAS/LAZ file(s).

You can refer to the [`justfile`](https://github.com/efpl-columbia/PointClouds.jl/blob/main/.justfile) for details, or if you want to copy a recipe to a script that can be run without having `just` installed.
The `just` recipes are also used for the GitHub actions that are run whenever new commits are pushed to the repository.

## Creating a Release

1) Make sure that all tests pass (including doctests) and that the automatic formatting has run over all new code.
2) Create a new commit that updates the version number in `Project.toml`.
3) Push the commit to a development branch and make sure that all the CI checks are passing.
4) Push or merge the commit into the `main` branch and comment `@JuliaRegistrator register` on the commit.
5) Wait for the new version to be published in the Julia package registry.
6) Create a new tag with `git tag v0.0.0` and push it to GitHub with `git push origin v0.0.0` (substitute version number).

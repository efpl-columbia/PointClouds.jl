# This file contains recipes for the `just` command runner.
# See https://github.com/casey/just for more information.
set positional-arguments

formatter_version := "1.0.45"

_default:
  @just --list

# Start a REPL that already has the package loaded
repl:
  #!/usr/bin/env -S julia --project --load
  using PointClouds

# Run automated tests with (optional) arguments
test *params:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(".")
  # try-block used to suppress unnecessary stacktrace in output
  try Pkg.test(test_args = ARGS) catch end

# Apply formatting rules to code and tests
format:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  Pkg.add(Pkg.PackageSpec(name="JuliaFormatter", version="{{formatter_version}}"))
  import JuliaFormatter
  JuliaFormatter.format(["src", "test"])

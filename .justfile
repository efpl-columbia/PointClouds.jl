# This file contains recipes for the `just` command runner.
# See https://github.com/casey/just for more information.
set positional-arguments

documenter_version := "1.4.1"
liveserver_version := "1.3.1"
formatter_version := "1.0.45"
revise_version := "3.5.14"

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

# Build documentation to `docs/build` folder
makedocs:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  empty!(LOAD_PATH)
  push!(LOAD_PATH, "@", "@stdlib")
  Pkg.develop(path = ".")
  Pkg.add(Pkg.PackageSpec(name="Documenter", version="{{documenter_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  include(joinpath(pwd(), "docs", "make.jl"))

# Launch a local server for the documentation
servedocs:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  empty!(LOAD_PATH)
  push!(LOAD_PATH, "@", "@stdlib")
  Pkg.develop(path = ".")
  Pkg.add(Pkg.PackageSpec(name="Documenter", version="{{documenter_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  Pkg.add(Pkg.PackageSpec(name="LiveServer", version="{{liveserver_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  Pkg.add(Pkg.PackageSpec(name="Revise", version="{{revise_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  import LiveServer, Revise
  ENV["PRETTY_URLS"] = "true"
  LiveServer.servedocs(; include_dirs = ["src"])

# Apply formatting rules to code and tests
format:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  Pkg.add(Pkg.PackageSpec(name="JuliaFormatter", version="{{formatter_version}}"))
  import JuliaFormatter
  JuliaFormatter.format(["src", "test"])

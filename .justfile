# This file contains recipes for the `just` command runner.
# See https://github.com/casey/just for more information.
set positional-arguments

# package versions for recipe dependencies
benchmarktools_version := "1.5.0"
documenter_version := "1.4.1"
formatter_version := "1.0.56"
liveserver_version := "1.3.1"
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
  # replace relative paths in `--pdal` argument, since Pkg.test changes directory
  replace!(a -> startswith(a, "--pdal=") ? "--pdal=" * abspath(a[8:end]) : a, ARGS)
  # try-block used to suppress unnecessary stacktrace in output
  try Pkg.test(test_args = ARGS) catch end

# Run documetation tests
doctest:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  empty!(LOAD_PATH)
  push!(LOAD_PATH, "@", "@stdlib")
  Pkg.develop(path = ".")
  Pkg.add(Pkg.PackageSpec(name="Documenter", version="{{documenter_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  import Documenter, PointClouds
  Documenter.doctest(PointClouds)

# Download LAZ sample file to cache directory
getsample:
  #!/usr/bin/env julia
  haskey(ENV, "XDG_CACHE_HOME") || error("Set `XDG_CACHE_HOME` to run this recipe")
  import Pkg
  Pkg.activate(; temp=true)
  empty!(LOAD_PATH)
  push!(LOAD_PATH, "@", "@stdlib")
  Pkg.add(Pkg.PackageSpec(name="BaseDirs"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  Pkg.add(Pkg.PackageSpec(name="HTTP"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  import BaseDirs, HTTP
  dir = BaseDirs.User.cache(BaseDirs.Project("PointClouds"), "ScienceBase")
  mkpath(dir)
  path = joinpath(dir, "6413c497d34eb496d1ce956e.laz")
  isfile(path) && exit(0)
  HTTP.download("https://rockyweb.usgs.gov/vdelivery/Datasets/Staged/Elevation/LPC/Projects/Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR/MD_VA_Sandy_NCR_2014/LAZ/USGS_LPC_Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR_18SUJ322306.laz", path, ("Range" => "bytes=0-51489",))

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
format *params:
  #!/usr/bin/env julia
  import Pkg
  Pkg.activate(; temp=true)
  Pkg.add(Pkg.PackageSpec(name="JuliaFormatter", version="{{formatter_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED)
  import JuliaFormatter
  check = "-c" in ARGS || "--check" in ARGS # only check, do not apply
  paths = filter(!startswith('-'), ARGS)
  isempty(paths) && push!(paths, "src", "test")
  if !check
    ps = ['`' * relpath(p) * '/'^isdir(p) * '`' for p in paths]
    print("Formatting ", if length(ps) < 3
        join(ps, " and ")
      else
        string(join(ps[begin:end-1], ", "), ", and ", ps[end])
      end, "… ")
  end
  if !JuliaFormatter.format(paths; overwrite = !check)
    check ? exit(1) : println("[Done]")
  else
    check || println("[No changes]")
  end

# Run performance tests
benchmark *params:
  #!/usr/bin/env julia
  import Pkg
  let
    io = ("-v" in ARGS || "--verbose" in ARGS) ? stderr : devnull
    Pkg.activate(; temp=true, io)
    empty!(LOAD_PATH)
    push!(LOAD_PATH, "@", "@stdlib")
    Pkg.develop(path = "."; io)
    Pkg.add(Pkg.PackageSpec(name="BenchmarkTools", version="{{benchmarktools_version}}"); preserve = Pkg.PRESERVE_TIERED_INSTALLED, io)
  end
  include(joinpath(pwd(), "perf", "runbenchmarks.jl"))

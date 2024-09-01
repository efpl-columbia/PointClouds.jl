using PointClouds, BenchmarkTools, Statistics

const VERBOSE = "-v" in ARGS || "--verbose" in ARGS

function pdal_samples(; verbose)

  # commit pinned to PDAL v2.6.3 for reproducibility (can be bumped to current version occasionally)
  pdal_commit = "d37b077053116f4b76d360d379dbcaf890fd4a39"
  pdal_url = "https://github.com/PDAL/PDAL/raw/$pdal_commit/test/data/"
  pdal_samples = ["las/autzen_trim.las", "laz/autzen_trim.laz"]

  # determine sample directory from arguments
  any(startswith("--pdal"), ARGS) || return []
  pdal_arg = split(ARGS[findfirst(startswith("--pdal"), ARGS)], '=')
  dir = length(pdal_arg) == 2 ? pdal_arg[2] : mktempdir()
  verbose && println("Using directory `$(abspath(dir))` for LAS samples")
  mkpath(dir)

  # download sample files
  map(pdal_samples) do sample
    url = pdal_url * sample
    path = abspath(joinpath(dir, replace(sample, '/' => "-")))
    isfile(path) || PointClouds.IO.HTTP.download(url, path)
    path
  end
end

function load_samples(samples; verbose)
  suite = BenchmarkGroup()
  map(samples) do sample
    @assert isfile(sample)
    bmks = BenchmarkGroup()
    las = LAS(sample)
    npts = length(las)
    bmks["load"] = @benchmarkable LAS($sample)
    bmks["readpts"] = @benchmarkable LAS($sample; read_points = true)
    bmks["collect"] = @benchmarkable collect($las)
    bmks["coords"] = @benchmarkable coordinates($las)
    bmks["intensity"] = @benchmarkable intensity($las)
    bmks["random"] = @benchmarkable getindex($las, rand(1:$npts))
    bmks["iterate"] = @benchmarkable (for pt in $las; pt; end)
    if endswith(sample, "las")
      bmks["stream"] = @benchmarkable LAS($sample; read_points = :stream)
    end
    suite[basename(sample)] = bmks
  end
  verbose && println(suite)
  argind = findfirst(startswith("--seconds="), ARGS)
  seconds = isnothing(argind) ? 1 : parse(Int, split(ARGS[argind], '=')[end])
  bmks = run(suite; verbose, seconds)
  show_results(bmks; verbose)
end

function show_results(bmks; verbose)
  for (name, trials) in bmks
    println("========== Results for `$name` ==========")
    for (case, trial) in trials
      if verbose
        print(case, ": ")
        show(stdout, MIME("text/plain"), trial)
        print("\n\n")
      else
        # compact summary of benchmark times
        print(rpad(case, maximum(length.(keys(trials)))), " => ")
        time(f) = ((t, u) = split(summary(f(trial))[15:end-1]); string(t[1:4], ' ', u))
        printstyled("min "; color = :light_black)
        print(time(minimum), ", ")
        printstyled("median "; color = :light_black)
        print(time(median), ", ")
        printstyled("mean "; color = :light_black)
        print(time(mean), ", ")
        printstyled("max "; color = :light_black)
        print(time(maximum), ", ")
        printstyled("allocs "; color = :light_black)
        print(allocs(trial), "\n")
      end
    end
    println()
  end
end

let verbose = VERBOSE
  samples = abspath.(filter(!startswith('-'), ARGS))
  append!(samples, pdal_samples(; verbose))
  load_samples(reverse(samples); verbose)
end

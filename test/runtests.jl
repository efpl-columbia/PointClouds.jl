using Test, PointClouds
import Dates

const VERBOSE = "-v" in ARGS || "--verbose" in ARGS
const SUFFIX = "_test.jl"

@testset "PointClouds.jl" begin
  tests = sort(map(x -> x[1:end-length(SUFFIX)], filter(endswith(SUFFIX), readdir(@__DIR__))))
  selection = filter(!startswith('-'), ARGS)
  for test in selection
    test in tests || error("Unknown test category: $test")
  end
  for test in (isempty(selection) ? tests : selection)
    include(string(test, SUFFIX))
  end
end

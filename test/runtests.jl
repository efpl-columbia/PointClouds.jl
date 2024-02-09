using Test, PointClouds

const VERBOSE = "-v" in ARGS || "--verbose" in ARGS

@testset "PointClouds.jl" begin
  include("io_test.jl")
end

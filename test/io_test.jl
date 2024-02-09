include("pdal_samples.jl")

function run_io_tests(; verbose)
  @test_throws ErrorException read("io_test.jl", LAS)
  check_pdal_samples(; verbose = verbose)
end

@testset "Input & Output" run_io_tests(verbose = VERBOSE)

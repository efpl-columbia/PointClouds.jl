include("pdal_samples.jl")

function run_io_tests(; verbose)
  @test_throws ErrorException read("io_test.jl", LAS)

  # see https://github.com/ASPRSorg/LAS/wiki/LAS-ProjectID-Encoding-and-Representation
  guid_raw = [
    0x33,
    0x22,
    0x11,
    0x00,
    0x55,
    0x44,
    0x77,
    0x66,
    0x88,
    0x99,
    0xAA,
    0xBB,
    0xCC,
    0xDD,
    0xEE,
    0xFF,
  ]
  guid = read(IOBuffer(guid_raw), PointClouds.IO.GUID)
  @test string(guid) == "00112233-4455-6677-8899-AABBCCDDEEFF"
  guid = PointClouds.IO.GUID(
    0x00112233,
    0x4455,
    0x6677,
    (0x4D, 0x79, 0x50, 0x72, 0x6F, 0x6A, 0x30, 0x31),
  )
  @test sprint(show, guid) == "00112233-4455-6677-4D79-50726F6A3031 \"MyProj01\""

  check_pdal_samples(; verbose = verbose)
end

@testset "Input & Output" run_io_tests(verbose = VERBOSE)

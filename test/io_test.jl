include("pdal_samples.jl")

function test_guid()
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
end

function test_las_create()

  # basics
  @test LAS() isa LAS
  @test_throws ErrorException read("io_test.jl", LAS)
  # point record data format
  @test eltype(LAS(PointRecord{1})) <: PointRecord{1}
  @test isconcretetype(eltype(LAS(PointRecord{1}).points))
  @test allequal(eltype.((LAS(), LAS(PointRecord{6}), LAS(PointRecord{6,0}))))
  @test eltype(LAS(PointRecord{6})) != eltype(LAS(PointRecord{6,1}))
  @test_throws ArgumentError LAS(PointRecord{22})
  # las version
  @test LAS().version == (1, 4)
  @test LAS(; version = v"1.3").version == (1, 3)
  @test allequal(LAS(; version = v).version for v in (1.3, "1.3", v"1.3"))
  @test_throws ArgumentError LAS(version = 1.5)
  # software id
  @test LAS().software_id == "PointClouds.jl"
  @test LAS(; software_id = "something").software_id == "something"
  @test_throws ArgumentError LAS(
    software_id = "something longer than the maximum length of 32 characters",
  )
  # creation date
  @test LAS(; creation_date = Dates.Date("2020-03-01")).creation_date == (31 + 29 + 1, 2020)

  # create from julia data
  data = (x = 1:5, y = 101:105, z = 100:100:500)
  las = LAS(data)
  @test las isa LAS
  @test las.coord_offset == (0.0, 100.0, 0.0)
  @test las.coord_scale == (1e-8, 1e-8, 1e-6)
  @test coordinates(las, 1) == (data.x[1], data.y[1], data.z[1])

  # change LAS headers
  @test update(las; system_id = "custom").system_id == "custom"
  @test coordinates(update(las; system_id = "custom"), 2)[end] == data.z[2]
  @test_throws ArgumentError update(las; system_id = "something longer than 32 characters")

  # write with different headers
  tmp = tempname()
  write(tmp, update(las; system_id = "custom"))
  @test LAS(tmp).system_id == "custom"
  @test coordinates(LAS(tmp), 1) == (data.x[1], data.y[1], data.z[1])

  # read headers without points
  let las = LAS(tmp; read_points = false)
    @test length(las) == 5
    @test_throws ErrorException las[1]
  end

  # create & write subset of points
  @test las[1:3] == las[(1:5).<=3]
  @test extrema(las[2:4]) == ((2.0, 102.0, 200.0), (4.0, 104.0, 400.0))
  @test coordinates(las[2:2:end], 1) == (2.0, 102.0, 200.0)
  @test coordinates(las[2:2:end], 2) == (4.0, 104.0, 400.0)
  @test las[2:2:end][end] == las[4] == las[iseven.(1:5)][end] == las[4:5][1]
  write(tmp, las[1:3])
  @test length(LAS(tmp)) == 3
  @test LAS(tmp)[2:3] == LAS(tmp)[(1:3).>1] == las[2:3]

  # filtering of LAS points
  coords = coordinates(Function, las)
  @test las[1:3] == filter(pt -> coords(pt)[1] <= 3, las)
  @test las[2:4] == filter(las; x = (2, 4)) == filter(las; lon = (2, 4))
  @test las[2:4] == filter(las; y = (102, 104)) == filter(las; lat = (102, 104))
  @test las[2:4] == filter(las; z = (200, 400))

  # update with new attributes
  las2 = update(las, (classification = 11:15,))
  @test las2 isa LAS
  @test classification(las2, :) == classification.(las2) == 11:15
  @test classification(las2, 2:4) == 12:14
end

function test_las_update()
  data = (
    x = 1:5,
    y = 101:105,
    z = 100:100:500,
    scan_angle = 15_000 .* (-2:2),
    return_number = [1, 2, 3, 1, 2],
    return_count = [3, 3, 3, 2, 2],
  )
  las = LAS(data)
  @test scan_angle.(las) == [-180, -90, 0, 90, 180]
  @test return_number.(las) == data.return_number
  @test return_count.(las) == data.return_count
  new_returns = [3, 2, 1, 2, 1]
  @test return_number.(update(las, (return_number = new_returns,))) == new_returns
end

function hasattr(pdrf, attr)
  attr == color_channels && return pdrf in (2, 3, 5, 7, 8, 10)
  attr == gps_time && return !(pdrf in (0, 2))
  attr == waveform_packet && return pdrf in (4, 5, 9, 10)
  attr == scanner_channel && return pdrf >= 6
  true
end

function test_attributes()
  @testset "PointRecord{$pdrf,$nextra}" for pdrf in 1:10, nextra in (0, 2)
    las = LAS(PointRecord{pdrf,nextra})
    P = eltype(las)
    append!(las.points, reinterpret(P, rand(UInt8, sizeof(P) * 10)))
    @testset "$attr" for attr in (
      classification,
      color_channels,
      coordinates,
      extra_bytes,
      gps_time,
      intensity,
      is_edge_of_line,
      is_key_point,
      is_left_to_right,
      is_overlap,
      is_right_to_left,
      is_synthetic,
      is_withheld,
      return_count,
      return_number,
      scan_angle,
      scanner_channel,
      source_id,
      user_data,
      waveform_packet,
    )
      ref = attr(las)
      if hasattr(pdrf, attr)
        @test all(attr(las, :) .=== ref)
        @test all(attr(las, 1:10) .=== ref)
        @test all(attr(las, 2:9) .=== ref[2:9])
        @test attr(las, 5) === ref[5]
        attr == coordinates && (attr = attr(Function, las))
        @test attr(las[5]) === ref[5]
      else
        @test ismissing.(ref) == trues(10)
        @test ismissing.(attr(las, :)) == trues(10)
        @test ismissing.(attr(las, 1:10)) == trues(10)
        @test ismissing.(attr(las, 2:9)) == trues(8)
        @test ismissing(attr(las, 5))
        @test ismissing(attr(las[5]))
      end
    end
  end
end

function test_read_allocs()
  noallocs(f, args) = isempty(check_allocs(f, args))

  # check functions handling single point
  P = PointClouds.IO.PointRecord3{2}
  @test noallocs(coordinates, (Type{Integer}, P))
  @test noallocs(intensity, (P,))

  # check functions handling memory-mapped & laszip points
  Pm = PointClouds.IO.MappedPoints{P}
  Pz = PointClouds.IO.LASzipReader{P}
  for Ps in (Pm, Pz)
    L = LAS{Ps,Vector{PointClouds.IO.VariableLengthRecord}}
    @test noallocs(getindex, (L, Int))
    @test noallocs(coordinates, (L, Int))
    @test noallocs(intensity, (L, Int))
    @test noallocs(foreach, (typeof(identity), L))
  end
end

function run_io_tests(; verbose)
  test_guid()
  test_las_create()
  test_las_update()
  @testset "Access point attributes" redirect_stdio(test_attributes; stderr = devnull)
  test_read_allocs()
  check_pdal_samples(; verbose = verbose)
end

@testset "Input & Output" run_io_tests(verbose = VERBOSE)

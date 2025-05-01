function run_gettiles_tests(; verbose)
  coords = (38.897778, -77.036389) # lat/lon
  crs = "EPSG:26918" # UTM 18N
  utm = (323_404, 4_307_404) # same as coords

  # single point query
  t1 = gettiles(coords)
  t2 = gettiles(; lat = coords[1], lon = coords[2])
  t3 = gettiles(; x = coords[2], y = coords[1])
  t4 = gettiles(; x = utm[1], y = utm[2], crs)
  @test only(t1) == only(t2) == only(t3) == only(t4)

  # bounding-box query (two points)
  t5 = gettiles(; lat = coords[1] .+ (0, 1e-3), lon = coords[2] .+ (0, 1e-3))
  t6 = gettiles(; x = utm[1] .+ (0, 10), y = utm[2] .+ (0, 10), crs)
  @test only(t1) == only(t5) == only(t6)

  # polygon query (>2 points)
  t7 = gettiles(; lat = coords[1] .+ (0, 1e-3, 1e-3), lon = coords[2] .+ (0, 0, 1e-3))
  t8 = gettiles(; x = utm[1] .+ (0, 10, 10), y = utm[2] .+ (0, 0, 10), crs)
  @test only(t1) == only(t7) == only(t8)

  # fetch header of a tile, check that it is within 5km of location
  # (cache is skipped to make sure the download is working)
  # TODO: remove `insecure` once RockyWeb supports TLS again
  las = LAS(only(t1); read_points = false, cache = false, insecure = true)
  @test sqrt(sum(abs2, minimum(las)[1:2] .- utm)) < 5000
  @test sqrt(sum(abs2, minimum(las)[1:2] .- utm)) < 5000
end

@testset "Fetching Tiles" run_gettiles_tests(; verbose = VERBOSE)

function run_filter_tests(; verbose)
  # set up sample data
  coords = (x = 1:20, y = 41:60, z = range(0, 100, 20))
  pts = PointCloud(coords; crs = "EPSG:4326") # WGS 84

  # simple filtering by index
  @test pts[1:10].y == 41:50
  @test pts[end:-1:begin].y == 60:-1:41
  @test pts[2:19] == pts[begin+1:end-1]
  @test pts[1:2:10] == pts[[1, 3, 5, 7, 9]]
  @test pts[10:2:end] == pts[(pts.x.>=10).&&iseven.(pts.y)]

  # filter function for index-based filtering
  @test filter(pts; start = 2, step = 3) == pts[2:3:end]
  @test filter(pts; start = 2, step = 3, length = 4) == pts[2:3:11]
  @test filter(pts; stop = 8, length = 4) == pts[5:8]
  @test filter(pts; start = 10) == pts[10:end]
  @test filter(pts; start = 10, stop = 16, length = 3) == pts[10:3:16]
  @test filter(pts; start = 10, stop = 17, length = 3) == pts[10:3:16]
  @test filter(pts; step = 5, length = 3) == pts[1:5:11]
  @test filter(pts; step = 5, stop = 12) == pts[1:5:12]
  @test_throws ArgumentError filter(pts; start = 10, stop = 11, length = 3)

  # filter function with BitArray indexing
  @test filter(pts, pts.x .> 10) == pts[11:20]
  @test filter(pts, pts.x .> 10; length = 5) == pts[11:15]
  @test filter(pts, 5 .< pts.x .< 15; step = 2) == pts[6:2:14]

  # filter function for range/bounding-box indexing
  @test filter(pts; x = (0, 10)).y == 41:50
  @test filter(pts; x = (0, 10), y = (0, 45)).y == 41:45
  @test filter(pts; x = (0, 10)) == filter(pts; lon = (0, 10))
  @test filter(pts; y = (40, 50)) == filter(pts; lat = (40, 50))
  @test filter(pts; z = (0, 50)).z == range(0, 100, 20)[1:10]
  @test filter(pts; x = (5 + eps(), 15 - eps())).x == 5:15
  @test_throws ArgumentError filter(pts; x = (0, 10), lon = (0, 45))
  @test_throws ArgumentError filter(pts; y = (0, 10), lat = (0, 45))

  # filter with bounding box in different coordinate system (CH LV95)
  @test filter(pts; x = (2_500_000, 2_800_000), crs = "EPSG:2056").x == 7:10
  @test filter(pts; y = (1_000_000, 1_300_000), crs = "EPSG:2056").y == 46:47
end

@testset "Filtering" run_filter_tests(; verbose = VERBOSE)

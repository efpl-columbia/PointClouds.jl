function run_pointcloud_tests(; verbose)
  # setting up a basic point cloud from manually specified input data
  data = (x = (1, 2, 3, 4, 5), y = (1, 2, 3, 4, 5), z = (1, 2, 3, 4, 5).^2, intensity = (1, 2, 3, 4, 5))
  pts = PointCloud(data)

  # array-style access of individual points
  @test length(pts) == 5
  @test (pts[3].x, pts[3].y, pts[3].z, pts[3].intensity) == (3, 3, 9, 3)
  @test (pts[begin].x, pts[end].x) == (1, 5)

  # dictionary-style access of columnar data
  @test sort(collect(keys(pts))) == [:intensity, :x, :y, :z]
  @test haskey(pts, :intensity)
  @test all(pts[:x] .== 1:5)

  # property-based access also works for columnar data
  @test all(pts.x .== 1:5)
  @test pts.x isa Vector{Float64} # coordinates are always stored as Float64
  @test pts.intensity isa Vector{Int} # other fields are stored with the type of the input

  # compute new columns by looping over points
  ind_near_origin = map(eachindex(pts), pts.x, pts.y, pts.z) do ind, x, y, z
    d = sqrt(x^2 + y^2 + z^2)
    d <= 5 ? ind : 0
  end
  @test ind_near_origin == [1, 2, 0, 0, 0]
  pts.ind_near_origin = ind_near_origin
  pts[:near_origin] = ind_near_origin .> 0
  @test (pts[:ind_near_origin] .> 0) == pts.near_origin
  @test_throws ArgumentError pts.too_short = [1, 2, 3, 4]
  origin_distance = apply(pts, :x, :y, :z) do x, y, z
    sqrt(x^2 + y^2 + z^2)
  end
  @test origin_distance == [sqrt(2 * i^2 + i^4) for i in 1:5]

  # k nearest neighbors
  neighbors!(pts, 3)
  @test pts.neighbors == neighbors(pts, 3)
  @test length(eltype(pts.neighbors)) == 3
  @test pts.neighbors == [[2, 3, 4], [1, 3, 4], [2, 4, 1], [3, 5, 2], [4, 3, 2]]
  nb_min = apply(minimum, pts, :z; neighbors = true)
  @test nb_min isa Vector{Float64}
  @test nb_min == [1, 1, 1, 4, 4]
  @test nb_min == apply(minimum, pts, :z; neighbors = neighbors(pts, 3))
  @test nb_min == apply(minimum, pts, :z; neighbors = 3)
  @test nb_min != apply(minimum, pts, :z; neighbors = 2)

  # rasterized point cloud data
  r = rasterize(pts, (3, 3); extent = ((0, 0), (7, 7)))
  @test eltype(eltype(r.x)) == Float64
  count = map(xs -> length(xs), r.x)
  @test count == [2 0 0; 0 2 0; 0 0 1]
  mean_height = map(r.z) do zs
    isempty(zs) ? missing : sum(zs) / length(zs)
  end
  @test eltype(mean_height) == Union{Float64,Missing}

  # rasterize by footprint
  rf = rasterize(pts, (3, 3); extent = ((0, 0), (7, 7)), radius = 1e-3)
  @test map(length, rf.z) == zeros(3, 3)
  rf = rasterize(pts, (3, 3); extent = ((0, 0), (7, 7)), radius = 100)
  @test map(length, rf.z) == ones(3, 3) * 5
  rf = rasterize(pts, (3, 3); extent = ((0, 0), (7, 7)), radius = 3)
  @test map(length, rf.x) == [3 4 0; 4 4 3; 0 3 2]
  @test map(xs -> maximum(xs, init = 0), rf.x) == [3 4 0; 4 5 5; 0 5 5]
  rf = rasterize(pts, (3, 3); extent = ((2, 0), (4, 18)), radius = 4)
  @test map(length, rf.x) == [j == 1 ? 5 : 0 for i in 1:3, j in 1:3]

  # rasterize by neighbors (need to break symmetry in tests)
  rf = rasterize(pts, (3, 3); extent = ((0, 0), (8, 7)), neighbors = 2)
  @test map(collect, rf.x)[:] == [[1,2],[3,2],[4,3],[2,3],[4,3],[5,4],[4,3],[5,4],[5,4]]
end

@testset "PointCloud Type" run_pointcloud_tests(verbose = VERBOSE)

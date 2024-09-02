# commit pinned to PDAL v2.6.3 for reproducibility (can be bumped to current version occasionally)
const pdal_commit = "d37b077053116f4b76d360d379dbcaf890fd4a39"
const pdal_url = "https://github.com/PDAL/PDAL/raw/$pdal_commit/test/data/"
const pdal_samples = [
  "las/100-points.las",
  "las/1.2-empty-geotiff-vlrs.las" => (; vlr_reserved = 10),
  "las/1.2-with-color-clipped.las" => (; legacy_counts = 2),
  "las/1.2-with-color.las",
  "las/4_1.las" => (; point_counts = 2),
  "las/4_6.las" => (; legacy_counts = 12),
  "las/autzen_trim_7.las" => (; legacy_counts = 11),
  "las/autzen_trim.las",
  "las/bad-geotiff-keys.las" => (; legacy_counts = 1),
  "las/epsg_4326.las" => (; legacy_counts = 2),
  "las/extrabytes.las",
  "las/garbage_nVariableLength.las" =>
    (; global_encoding = 2, legacy_counts = 3, point_data = 14, vlr_count = 4),
  "las/gps-time-nan.las",
  "las/hextest.las",
  "las/interesting.las" => (; vlr_reserved = 10),
  "las/lots_of_vlr.las" => (; vlr_reserved = 776),
  "las/mvk-thin.las" => (; vlr_reserved = 10),
  "las/noise-clean.las",
  "las/noise-dirty.las",
  "las/no-points.las" => (; vlr_reserved = 8),
  "las/permutations/1.0_0.las" => (; vlr_reserved = 6),
  "las/permutations/1.0_1.las" => (; vlr_reserved = 6),
  "las/permutations/1.1_0.las",
  "las/permutations/1.1_1.las",
  "las/permutations/1.2_0.las",
  "las/permutations/1.2_1.las",
  "las/permutations/1.2_2.las",
  "las/permutations/1.2_3.las",
  "las/permutations/1.2-no-points.las" => (; legacy_counts = 7),
  "las/prec3.las",
  "las/sample_c.las" => (; bounding_box = 4, legacy_counts = 5),
  "las/sample_c_thin.las",
  "las/sample_nc.las" => (; bounding_box = 4, legacy_counts = 5),
  "las/simple.las",
  "las/spec_3.las",
  "las/spurious.las" => (; bounding_box = 7, vlr_reserved = 8),
  "las/synthetic_test.las",
  "las/test1_4.las" => (; legacy_counts = 7),
  "las/test_epsg_4047.las" => (; bounding_box = 8),
  "las/test_epsg_4326_axis.las",
  "las/test_epsg_4326.las" => (; bounding_box = 8),
  "las/test_epsg_4326x3.las",
  "las/test_utm16.las",
  "las/test_utm17.las",
  "las/utm15.las" => (; bounding_box = 4),
  "las/utm17.las",
  "las/wontcompress3.las" => (; legacy_counts = 6),
  # expected mismatch for LAZ files is based on reading them as if they were LAS
  "laz/autzen_trim.laz" => (; pdrf_number = 1, point_data = 3737654, vlr_reserved = 2),
  "laz/simple-laszip-compressor-version-1.2r0.laz" =>
    (; pdrf_number = 1, point_data = 36079, vlr_reserved = 2),
  "laz/simple.laz" => (; pdrf_number = 1, point_data = 36146, vlr_reserved = 2),
  "laszip/basefile.las",
  "laszip/laszip-generated.laz" =>
    (; pdrf_number = 1, point_data = 36146, vlr_reserved = 2),
  "laszip/laszip-generated_with2bytespadding.laz" =>
    (; pdrf_number = 1, point_data = 36146, vlr_reserved = 2),
  "laszip/liblas-generated.laz" =>
    (; pdrf_number = 1, point_data = 36141, vlr_reserved = 2),
]

"""
Download and check LAS test files from PDAL. This only runs if it is explicitly
requested with the `--pdal` command-line argument and downloads the sample
files to a temporary folder. To avoid re-downloading the files use the
argument `--pdal=folder` instead, where `folder` is the path where the files
should be stored (absolute or relative to the working directory, which is
`test` when run with `Pkg.test`).
"""
function check_pdal_samples(; verbose)
  any(startswith("--pdal"), ARGS) || return
  pdal_arg = split(ARGS[findfirst(startswith("--pdal"), ARGS)], '=')
  dir = length(pdal_arg) == 2 ? pdal_arg[2] : mktempdir()
  verbose && println("Using directory `$(abspath(dir))` for LAS samples")
  mkpath(dir)
  samples = map(s -> s isa String ? s => (;) : s, pdal_samples)
  @testset "Check PDAL sample files in `$dir`" begin
    @testset "$sample" for (sample, expected_mismatch) in samples
      endswith(sample, ".las") || continue # skip LAZ files for now
      redirect_stderr(verbose ? stderr : devnull) do
        verbose && println(stderr, "→ $(sample)")
        path_in = joinpath(dir, replace(sample, '/' => "-"))
        @test expected_mismatch == let
          las = LAS(pdal_url * sample; cache = path_in)
          println(stderr, las)
          mismatch = mktemp() do path_out, io
            write(io, las)
            close(io)
            compare_files(path_in, path_out)
          end
          interpret_mismatch(mismatch, las)
        end
        if !occursin("garbage", sample)
          @test let
            las = LAS(path_in)
            laz = LAS(path_in; read_points = :laszip)
            all(las[i] == laz[i] for i in 1:length(las))
          end
        end
        println(stderr)
      end
    end
  end
end

function compare_files(paths...)
  data = read.(paths)
  n, N = extrema(length.(data))
  mismatch = findall(!allequal(d[i] for d in data) for i in 1:n)
  append!(mismatch, n+1:N)
  mismatch
end

function interpret_mismatch(mismatch, las)
  classified, other = Dict(), Int[]
  classify_mismatch(k) = (classified[k] = get(classified, k, 0) + 1)
  unknown_mismatch(x) = push!(other, x)

  header_size = (227, 227, 227, 235, 375)[las.version[2]+1]
  vlr_sizes = [54 + length(vlr.data) for vlr in las.vlrs]
  vlr_offsets = [header_size + sum(vlr_sizes[1:i-1]) for i in 1:length(las.vlrs)]
  point_offset = header_size + sum(vlr_sizes) + length(las.extra_data)

  for ind in mismatch
    if ind in 7:8
      classify_mismatch(:global_encoding)
    elseif ind in 101:104
      classify_mismatch(:vlr_count)
    elseif ind == 105
      classify_mismatch(:pdrf_number)
    elseif ind in 108:131
      classify_mismatch(:legacy_counts)
    elseif ind in 180:227
      classify_mismatch(:bounding_box)
    elseif ind in 248:375 && las.version[2] >= 4
      classify_mismatch(:point_counts)
    elseif any((ind == o + 1 || ind == o + 2) for o in vlr_offsets)
      classify_mismatch(:vlr_reserved)
    elseif ind > point_offset
      classify_mismatch(:point_data)
    else
      unknown_mismatch(ind)
    end
  end

  (; sort(collect(classified))..., (isempty(other) ? () : (:other_bytes => other,))...)
end

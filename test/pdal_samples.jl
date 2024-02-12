using Downloads: Downloads

# commit pinned to PDAL v2.6.3 for reproducibility (can be bumped to current version occasionally)
const pdal_commit = "d37b077053116f4b76d360d379dbcaf890fd4a39"
const pdal_url = "https://github.com/PDAL/PDAL/raw/$pdal_commit/test/data/las/"
const pdal_samples = [
  "100-points.las",
  "1.2-empty-geotiff-vlrs.las" => [:vlr_reserved => 10],
  "1.2-with-color-clipped.las" => [:legacy_counts => 2],
  "1.2-with-color.las",
  "4_1.las" => [:point_counts => 2],
  "4_6.las" => [:legacy_counts => 12],
  "autzen_trim_7.las" => [:legacy_counts => 11],
  "autzen_trim.las",
  "bad-geotiff-keys.las" => [:legacy_counts => 1],
  "epsg_4326.las" => [:legacy_counts => 2],
  "extrabytes.las",
  "garbage_nVariableLength.las" => [:global_encoding => 2, :legacy_counts => 3, :point_data => 14, :vlr_count => 4],
  "gps-time-nan.las",
  "hextest.las",
  "interesting.las" => [:vlr_reserved => 10],
  "lots_of_vlr.las" => [:vlr_reserved => 776],
  "mvk-thin.las" => [:vlr_reserved => 10],
  "noise-clean.las",
  "noise-dirty.las",
  "no-points.las" => [:vlr_reserved => 8],
  "permutations/1.0_0.las" => [:vlr_reserved => 6],
  "permutations/1.0_1.las" => [:vlr_reserved => 6],
  "permutations/1.1_0.las",
  "permutations/1.1_1.las",
  "permutations/1.2_0.las",
  "permutations/1.2_1.las",
  "permutations/1.2_2.las",
  "permutations/1.2_3.las",
  "permutations/1.2-no-points.las" => [:legacy_counts => 7],
  "prec3.las",
  "sample_c.las" => [:bounding_box => 4, :legacy_counts => 5],
  "sample_c_thin.las",
  "sample_nc.las" => [:bounding_box => 4, :legacy_counts => 5],
  "simple.las",
  "spec_3.las",
  "spurious.las" => [:bounding_box => 7, :vlr_reserved => 8],
  "synthetic_test.las",
  "test1_4.las" => [:legacy_counts => 7],
  "test_epsg_4047.las" => [:bounding_box => 8],
  "test_epsg_4326_axis.las",
  "test_epsg_4326.las" => [:bounding_box => 8],
  "test_epsg_4326x3.las",
  "test_utm16.las",
  "test_utm17.las",
  "utm15.las" => [:bounding_box => 4],
  "utm17.las",
  "wontcompress3.las" => [:legacy_counts => 6],
]

"""
Download and check LAS test files from PDAL. This only runs if it is explicitly
requested with the `--pdal` command-line argument and downloads the sample
files to a temporary folder. To avoid re-downloading the files use the
argument `--pdal=folder` instead, where `folder` is the path where the files
should be stored (absolute or relative to the `test` folder).
"""
function check_pdal_samples(; verbose)
  any(startswith("--pdal"), ARGS) || return
  pdal_arg = split(ARGS[findfirst(startswith("--pdal"), ARGS)], '=')
  dir = length(pdal_arg) == 2 ? pdal_arg[2] : mktempdir()
  verbose && println("Using directory `$(abspath(dir))` for LAS samples")
  mkpath(dir)
  samples = map(s -> s isa String ? s => [] : s, pdal_samples)
  @testset "Check PDAL sample files in `$dir`" begin
    @testset "$sample" for (sample, expected_mismatch) in samples
      verbose && println("→ $(sample)")
      path_in = joinpath(dir, replace(sample, '/' => "--"))
      isfile(path_in) || Downloads.download(pdal_url * sample, path_in)
      path_out = tempname() * ".las"
      @test expected_mismatch == let
        las = if verbose
          las = read(path_in, LAS)
          display(las)
          write(path_out, las)
          println()
          las
        else
          redirect_stderr(devnull) do
            las = read(path_in, LAS)
            write(path_out, las)
            las
          end
        end
        mismatch = compare_files(path_in, path_out)
        interpret_mismatch(mismatch, las)
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
  classified, other = Dict(), []
  classify_mismatch(k) = (classified[k] = get(classified, k, 0) + 1)
  unknown_mismatch(x) = push!(other, x)

  header_size = (227, 227, 227, 235, 375)[las.version[2] + 1]
  vlr_sizes = [54 + length(vlr.data) for vlr in las.vlrs]
  vlr_offsets = [header_size + sum(vlr_sizes[1:i-1]) for i in 1:length(las.vlrs)]
  point_offset = header_size + sum(vlr_sizes) + length(las.extra_data)

  for ind in mismatch
    if ind in 7:8
      classify_mismatch(:global_encoding)
    elseif ind in 101:104
      classify_mismatch(:vlr_count)
    elseif ind in 108:131
      classify_mismatch(:legacy_counts)
    elseif ind in 180:227
      classify_mismatch(:bounding_box)
    elseif ind in 248:375 && las.version[2] >= 4
      classify_mismatch(:point_counts)
    elseif any((ind == o+1 || ind == o+2) for o in vlr_offsets)
      classify_mismatch(:vlr_reserved)
    elseif ind > point_offset
      classify_mismatch(:point_data)
    else
      unknown_mismatch(ind)
    end
  end

  [sort(collect(classified)); other]
end

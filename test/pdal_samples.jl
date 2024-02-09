using Downloads: Downloads

# commit pinned to PDAL v2.6.3 for reproducibility (can be bumped to current version occasionally)
const pdal_commit = "d37b077053116f4b76d360d379dbcaf890fd4a39"
const pdal_url = "https://github.com/PDAL/PDAL/raw/$pdal_commit/test/data/las/"
const pdal_samples = [
  "100-points.las",
  "1.2-empty-geotiff-vlrs.las",
  "1.2-with-color-clipped.las",
  "1.2-with-color.las",
  "4_1.las",
  "4_6.las",
  "autzen_trim_7.las",
  "autzen_trim.las",
  "bad-geotiff-keys.las",
  "epsg_4326.las",
  "extrabytes.las",
  "garbage_nVariableLength.las",
  "gps-time-nan.las",
  "hextest.las",
  "interesting.las",
  "lots_of_vlr.las",
  "mvk-thin.las",
  "noise-clean.las",
  "noise-dirty.las",
  "no-points.las",
  "permutations/1.0_0.las",
  "permutations/1.0_1.las",
  "permutations/1.1_0.las",
  "permutations/1.1_1.las",
  "permutations/1.2_0.las",
  "permutations/1.2_1.las",
  "permutations/1.2_2.las",
  "permutations/1.2_3.las",
  "permutations/1.2-no-points.las",
  "prec3.las",
  "sample_c.las",
  "sample_c_thin.las",
  "sample_nc.las",
  "simple.las",
  "spec_3.las",
  "spurious.las",
  "synthetic_test.las",
  "test1_4.las",
  "test_epsg_4047.las",
  "test_epsg_4326_axis.las",
  "test_epsg_4326.las",
  "test_epsg_4326x3.las",
  "test_utm16.las",
  "test_utm17.las",
  "utm15.las",
  "utm17.las",
  "wontcompress3.las",
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
  @testset "Check PDAL sample files in `$dir`" begin
    @testset "$sample" for sample in pdal_samples
      verbose && println("– $(sample)")
      path = joinpath(dir, replace(sample, '/' => "--"))
      isfile(path) || Downloads.download(pdal_url * sample, path)
      @test read(path, LAS) isa LAS
    end
  end
end

# PointClouds.jl

*Fast & flexible processing of lidar data*

[PointClouds.jl](https://github.com/efpl-columbia/PointClouds.jl) lets you
query publicly available lidar point-cloud datasets, download the data for
regions of interest, and explore & process the data locally. You can access all
attributes stored in [LAS/LAZ](https://en.wikipedia.org/wiki/LAS_file_format)
files and construct purpose-built processing pipelines that extract information
about the local environment from point-cloud data.

## Features & Goals

[![Online Documentation](https://img.shields.io/badge/🕮-Online_Documentation-2C6BAC)](https://docs.mfsch.dev/PointClouds.jl/)

PointClouds.jl aims to provide all functionality for an ergonomic,
high-performance workflow to acquire and process point-cloud data. The initial
development is focused on producing robust primitives for such a workflow.
Over time, we expect the functionality to expand, building out a comprehensive
library of point-cloud processing algorithms similar to
[PDAL](https://pdal.io/) and [lidR](https://r-lidar.github.io/lidRbook/).

- spatial queries of the [USGS 3DEP lidar
  data](https://www.usgs.gov/3d-elevation-program) with near-total coverage of
  the United States
- reading & writing [LAS/LAZ](https://en.wikipedia.org/wiki/LAS_file_format)
  files (v1.0 – v1.4), including files that do not fit into memory
- lazy filtering & updating of LAS/LAZ points
- parsing LAS coordinate reference system (CRS) data in WKT & GeoTIFF formats;
  coordinate transforms
- multi-threaded in-memory processing of point-cloud data, including
  neighborhood-based processing
- rasterization of point-cloud data based on points within pixel footprint,
  points within radius of pixel center, and *k* nearest neighbors of pixel
  center

For more details, see the [documentation](https://docs.mfsch.dev/PointClouds.jl).

## Quickstart

To start using PointClouds.jl, add it to a [Julia environment](https://pkgdocs.julialang.org/v1/getting-started/#Getting-Started-with-Environments) e.g. using the [Pkg REPL](https://pkgdocs.julialang.org/v1/getting-started/#Basic-Usage):

```julia-repl
(@v1.10) pkg> add PointClouds
```

> [!TIP]
> Since PointClouds.jl is rather new and under active development,
> backwards-incompatible changes may occur regularly. It is therefore
> recommended to add a specific version to your Julia environment (e.g. with
> [`Pkg.compat`](https://pkgdocs.julialang.org/v1/api/#Pkg.compat) or
> [`Pkg.pin`](https://pkgdocs.julialang.org/v1/api/#Pkg.pin) and to be careful
> when updating to new (non-patch) versions.

After that, the package can be loaded as usual:

```julia-repl
julia> using PointClouds
```

Load a LAS/LAZ file to access the point data:

```julia-repl
julia> pts = LAS("USGS_LPC_Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR_18SUJ322306.laz")
16,107,898-point LAZ (v1.2, PDRF 1, 01 Jun 2015)
  Source ID     => 65535
  Project ID    => AEB2BAA1-2BEF-41FC-B9BB-BDA288E8D77B
  System ID     => ""
  Software ID   => "GeoCue LAS Updater"
  X-Coordinates => 322500.0 … 323999.99
  Y-Coordinates => 4.3065e6 … 4.30799999e6
  Z-Coordinates => -88.88 … 767.73
  Return-Counts => [1 => 13,783,924, 2 => 1,993,048, 3 => 310,661, 4 => 19,622, 5 => 643]
  Extra Data    => [0x00, 0x00, 0xdd, 0xcc]
  Variable-Length Records
    => LASF_Projection[34735] "GeoTiff Projection Keys" (200 bytes)
    => LASF_Projection[34736] "GeoTiff double parameters" (80 bytes)
    => LASF_Projection[34737] "GeoTiff ASCII parameters" (217 bytes)
```

Refer to [the documentation](https://docs.mfsch.dev/PointClouds.jl) to learn how to [work with LAS/LAZ data](https://docs.mfsch.dev/PointClouds.jl/input-output/), [load point data from public datasets](https://docs.mfsch.dev/PointClouds.jl/data-sources/), and [set up in-memory processing pipelines](https://docs.mfsch.dev/PointClouds.jl/point-processing/). Follow [the tutorial](https://docs.mfsch.dev/PointClouds.jl/tutorial/) for a more in-depth introduction.

## Help & Contributing

If you run into a problem or would like to request a new feature, feel free to [create a new issue](https://github.com/efpl-columbia/PointClouds.jl/issues/new) after checking the [list of open issues](https://github.com/efpl-columbia/PointClouds.jl/issues).

We also welcome contributions to the code, the tests, and the documentation – feel free to open a [pull request](https://github.com/efpl-columbia/PointClouds.jl/pulls).
If you want to make sure your work fits within the plans and scope of PointClouds.jl, it might be best to first open an issue or draft PR to discuss the changes, especially when a significant amount of work is involved.

## Attribution & License

[![JOSS Paper](https://joss.theoj.org/papers/7885dd3306a23583dcf3963374c0c1cb/status.svg)](https://joss.theoj.org/papers/7885dd3306a23583dcf3963374c0c1cb)
[![MIT License](https://img.shields.io/badge/License-MIT-D2D2C0)](./LICENSE.md)

PointClouds.jl is freely available under the terms of the [MIT License](./LICENSE.md).
A [JOSS](https://joss.theoj.org/) paper describing PointClouds.jl is currently [under review](https://joss.theoj.org/papers/7885dd3306a23583dcf3963374c0c1cb).
Please cite this work if you use PointClouds.jl for your scientific publications.

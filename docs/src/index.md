# Explore & Process 3D Point-Cloud Data

```@meta
CurrentModule = PointClouds
```

[PointClouds.jl](https://github.com/efpl-columbia/PointClouds.jl) lets you
query publicly available lidar point-cloud datasets, download the data for
regions of interest, and explore & process the data locally. You can access all
attributes stored in [LAS/LAZ](https://en.wikipedia.org/wiki/LAS_file_format)
files and construct purpose-built processing pipelines that extract information
about the local environment from point-cloud data.

```@contents
Pages = ["index.md"]
Depth = 2:2
```

## Main features & goals

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

For more details, see the [table of contents](@ref "Contents of documentation") below.

### Use cases

PointClouds.jl is primarily designed to work with geospatial point-cloud data obtained from airborne lidar scans.
The typical use cases consist of loading such data from LAS/LAZ files and performing a series of processing steps such as filtering, classification, and rasterization to extract useful information from the raw point-cloud data.

A particular focus is given to these three use cases:

1) **LAS/LAZ file manipulation:** As a “Swiss army knife” for LAS/LAZ data, PointClouds.jl aims to adhere strictly to the specifications, make every byte available for reading and writing, and enable reading/writing larger-than-memory data in a streaming manner.
2) **Developing algorithms for point-cloud processing:** Thanks to its “just-ahead-of-time” compilation model, Julia is an excellent environment for iterative exploratory development that is performance-sensitive, as is the case when working with millions of points. PointClouds.jl provides primitives to quickly try out ideas for new point-cloud-processing algorithms and apply them to data for various locations.
3) **Lidar-based analyses for arbitrary locations:** Through the integration with national databases of lidar data, processing pipelines built on PointClouds.jl can be applied to new locations with ease.

### Related packages

The LAS/LAZ file support in PointClouds.jl was inspired by [LasIO.jl](https://github.com/visr/LasIO.jl) and [LazIO.jl](https://github.com/evetion/LazIO.jl).
While these are less complete in some areas such as CRS and LAS 1.4 support (as of May 2025), they have been stable for many years and can still be a good option if you are looking for a thin layer on top of the raw LAS/LAZ data.
The [LASDatasets.jl](https://github.com/fugro-oss/LASDatasets.jl) package is another more recent option for loading/writing LAS data that has more complete support for storing custom data in LAS files.
The specific use case of rasterizing larger-than-memory LAS files is covered by [PointCloudRasterizers.jl](https://github.com/Deltares-research/PointCloudRasterizers.jl) and not currently covered by PointClouds.jl, which in turn has more functionality for in-memory rasterization.

There are of course many other Julia packages that can be useful when working with point-cloud data, even when this is not their primary goal.
The [JuliaGeo](https://github.com/JuliaGeo/) and [JuliaEarth](https://github.com/JuliaEarth/) communities have built out a lot of functionality for working with geospatial data, so their work can be a good starting point before exploring the [broader package ecosystem](https://julialang.org/packages/).

## Installation

PointClouds.jl is available in the official Julia package registry.
Add it to a [Julia environment](https://pkgdocs.julialang.org/v1/getting-started/#Getting-Started-with-Environments) using e.g. the [Pkg REPL](https://pkgdocs.julialang.org/v1/getting-started/#Basic-Usage):

```julia-repl
(@v1.10) pkg> add PointClouds
```

Follow [the tutorial](@ref "Tutorial") for an introduction to the functionality of PointClouds.jl.

!!! note
    Since PointClouds.jl is rather new and under active development, backwards-incompatible changes may occur regularly.
    It is therefore recommended to add a specific version to your Julia environment (e.g. with [`Pkg.compat`](https://pkgdocs.julialang.org/v1/api/#Pkg.compat) or [`Pkg.pin`](https://pkgdocs.julialang.org/v1/api/#Pkg.pin) and to be careful when updating to new (non-patch) versions.

## Contents of documentation

```@contents
Pages = ["tutorial.md", "input-output.md", "point-processing.md", "data-sources.md", "development.md"]
Depth = 1:2
```

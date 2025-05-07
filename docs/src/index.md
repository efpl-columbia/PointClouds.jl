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

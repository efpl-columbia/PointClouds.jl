# Accessing Public Data Sources

```@meta
CurrentModule = PointClouds
```

PointClouds.jl aims to provide easy access to public databases of lidar
point-cloud data. Several countries have commissioned projects to produce
comprehensive lidar scans of their territory and make the resulting point-cloud
data freely available. While these projects usually have an online interface to
browse, query, and download their data, PointClouds.jl also includes such
functionality. This makes it possible to write code that takes target
coordinates as input and processes the local point-cloud data for any location
covered by the available databases.

```@contents
Pages = ["data-sources.md"]
Depth = 2:2
```

## Querying the databases

The [`gettiles`](@ref) function sends a spatial query to the available data
sources to obtain a list of point-cloud tiles that cover the area of interest.

```@docs
gettiles
```

Currently, PointClouds.jl supports downloading data from the [USGS 3D Elevation
Program (3DEP)](@ref), which covers most of the continental United States. The
`DataSource` argument of [`gettiles`](@ref) can be omitted for now, as
[`ScienceBase`](@ref) is the only available option. Support for further
databases is planned.

## Downloading point-cloud data

Tiles can be passed to the `LAS` constructor to load the point-cloud data.

```@docs
LAS(::PointClouds.DataSources.PointCloudTile)
```

!!! note
    There is currently [an
    issue](https://github.com/efpl-columbia/PointClouds.jl/issues/4#issuecomment-2806511668)
    with the SSL certificates of the RockyWeb server where the USGS LAS data is
    stored. Pass the keyword argument `insecure = true` to [`LAS`](@ref
    LAS(::PointClouds.DataSources.PointCloudTile)) to skip the certificate
    verification.

## USGS 3D Elevation Program (3DEP)

The [USGS 3D Elevation Program
(3DEP)](https://www.usgs.gov/3d-elevation-program) aims to provide nationwide
coverage of the United States with high-resolution lidar scans.
The raw point-cloud data is made available in the [ScienceBase catalog](https://www.sciencebase.gov/catalog/) as the [Lidar Point Cloud (LPC)](https://www.sciencebase.gov/catalog/item/4f70ab64e4b058caae3f8def) dataset.

!!! note
    The ScienceBase service does not always have the best availability. If the
    queries time out, check whether the [ScienceBase catalog
    website](https://www.sciencebase.gov/catalog/) is currently unavailable. If
    this is the case, try again later or fall back to manual browsing on the
    [USGS file
    server](https://rockyweb.usgs.gov/vdelivery/Datasets/Staged/Elevation/).
    Note that other USGS services such as the [3DEP Lidar
    Explorer](https://apps.nationalmap.gov/lidar-explorer/#/) and [TNM
    Access](https://apps.nationalmap.gov/tnmaccess/) also depend on ScienceBase
    to function.

```@docs
ScienceBase
```

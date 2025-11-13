# Tutorial

```@meta
CurrentModule = PointClouds
```

The workflow for processing point-cloud data depends on the goals of the analysis.
Here, we give a few examples of tasks that could be accomplished with PointClouds.jl.

```@contents
Pages = ["tutorial.md"]
Depth = 2:2
```


## Finding & loading LAS data

Let’s look at the surroundings of the [White House](https://en.wikipedia.org/wiki/White_House) for this example.
The Wikipedia page lists its coordinates as [38°53′52″N 77°02′11″W](https://geohack.toolforge.org/geohack.php?pagename=White_House&params=38_53_52_N_77_02_11_W_type:landmark_region:US-DC), and clicking that link we can get decimal coordinates:

```jldoctest tutorial
julia> white_house = (38.897778, -77.036389)
(38.897778, -77.036389)
```
We can now search for point-cloud data for that location.
First, we have to load the package:

```jldoctest tutorial
julia> using PointClouds
```

Then we can use [`gettiles`](@ref) to query [`ScienceBase`](@ref) for data from the [USGS 3D Elevation Program (3DEP)](@ref)

```jldoctest tutorial
julia> tiles = gettiles(white_house)
1-element Vector{PointClouds.DataSources.PointCloudTile}:
 ScienceBase(6413c497d34eb496d1ce956e): USGS Lidar Point Cloud Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR 18SUJ322306

julia> extrema(tiles[1])
((38.8894538536233, -77.0469626451088), (38.903264326206, -77.0292899951434))
```

!!! note
    Unfortunately, [there are multiple convention for the order of coordinates](https://docs.geotools.org/latest/userguide/library/referencing/order.html).
    The [`gettiles`](@ref) function accepts coordinate tuples in `(lat, lon)` order, which is the [EPSG:4326](https://epsg.io/4326) standard order for WGS 84 coordinates, even though this does not follow the typical $(x, y)$ order.
    It is recommended to use the keyword arguments `lat` & `lon` to avoid ambiguities.
    3D point-cloud data handled by PointClouds.jl should always have coordinates in $(x, y, z)$-order.

!!! warning
    The [ScienceBase catalog](https://www.sciencebase.gov/catalog/) is [not always working properly](https://github.com/efpl-columbia/PointClouds.jl/issues/4) so it is possible that `gettiles` results in an error.
    To continue with the tutorial, you can load the LAS data directly from the URL with the following command:
    ```julia-repl
    julia> las = LAS("https://rockyweb.usgs.gov/vdelivery/Datasets/Staged/Elevation/LPC/Projects/Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR/MD_VA_Sandy_NCR_2014/LAZ/USGS_LPC_Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR_18SUJ322306.laz")
    ```

We can load the data of this tile by passing it to the `LAS` constructor.
This will download the data to the local cache folder, if it has not been downloaded already.

```jldoctest tutorial
julia> las = LAS(tiles[1])
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

Here we can see an overview of the data contained within this LAZ file.
The header properties can be accessed with “dot syntax”, although this may return the “raw data” as it is stored within the LAS header:

```jldoctest tutorial
julia> las.source_id
0xffff

julia> las.coord_min, las.coord_max
((322500.0, 4.3065e6, -88.88), (323999.99, 4.30799999e6, 767.73))
```


## Accessing point attributes

The `LAS` behaves as a collection of `PointRecord`s similar to a `Vector`.

```jldoctest tutorial
julia> length(las)
16107898

julia> las[1]
PointRecord{1}(X = 32250320, Y = 430799725, Z = 5799, intensity = 0.00134279, return = 1/2, classification = 17, flags = [right-to-left], scan angle = +17°, GPS time = 8.23926e7, user data = 1, source ID = 8997)
```

We see that the points have a number of attributes, the exact subset of which depends on the “point data record format” (PDRF), which is “1” in this example.
Each attribute has a function to access it, which can be applied to points or (slightly more efficiently) to the `LAS`:

```jldoctest tutorial
julia> intensity(las[1])
0.0013427939269092851

julia> intensity(las, 1)
0.0013427939269092851

julia> intensity(las, 1:10)
10-element Vector{Float64}:
 0.0013427939269092851
 0.0001373311970702678
 9.155413138017853e-5
 0.00039673456931410697
 0.0006103608758678569
 0.00045777065690089265
 0.0008545052262149996
 0.000976577401388571
 0.0014648661020828565
 0.0020752269779507134
```

See “[Point data records and their attributes](@ref)” for details.


## Coordinates

The x-/y-/z-coordinates of a single point can not be accessed quite like that:

```jldoctest tutorial
julia> coordinates(las[1])
ERROR: MethodError: no method matching coordinates(::PointClouds.IO.PointRecord1{0})
[...]
```

This is because the LAS format stores coordinates as integer values that rely on a global scaling defined in the LAS header.
We can access these “raw” coordinate values by explicitly asking for them:

```jldoctest tutorial
julia> coordinates(Int, las[1])
(32250320, 430799725, 5799)
```

To get “real” coordinates, we can pass the `LAS` and the index as separate arguments:

```jldoctest tutorial
julia> coordinates(las, 1)
(322503.2, 4.30799725e6, 57.99)
```

We see here that these coordinates are very different from the coordinates of our original query.
This is because this LAS file is not using WGS 84 as its coordinate reference system (CRS).
We can look at the CRS data within the LAS:

```jldoctest tutorial
julia> getcrs(las)
(GTModelType = 0x0001, GTCitation = "PCS Name = NAD_1983_UTM_Zone_18N", GeodeticCRS = EPSG:4269, GeodeticCitation = "GCS Name = GCS_North_American_1983|Datum = North_American_1983|Ellipsoid = GRS_1980|Primem = Greenwich", GeodeticDatum = EPSG:6269, PrimeMeridian = EPSG:8901, GeogAngularUnits = EPSG:9102, GeogAngularUnitSize = 0.0, Ellipsoid = EPSG:7019, EllipsoidSemiMajorAxis = 500000.0, EllipsoidInvFlattening = 0.0, PrimeMeridianLongitude = -75.0, ProjectedCRS = EPSG:26918, ProjectedCitation = "NAD83 / UTM zone 18N|projection: Transverse Mercator", ProjMethod = 0x0001, ProjLinearUnits = EPSG:9001, ProjLinearUnitSize = 0.9996, ProjNatOriginLat = 1.0, ProjFalseEasting = 6.378137e6, ProjFalseNorthing = 298.2572221010042, ProjCenterLong = 0.0, ProjScaleAtNatOrigin = 0.017453292519943278, VerticalCitation = "NAVD88 - Geoid12A (Meters)", VerticalUnits = EPSG:9001)
```

This is the “raw” CRS data that is stored within the LAS, in this case using the CRS format defined in the [GeoTIFF standard](https://docs.ogc.org/is/19-008r4/19-008r4.html).
We may be able to determine manually that this is meant to describe NAD83/UTM zone 18N coordinates ([EPSG:26918](https://epsg.io/26918)), but PointClouds.jl can also interpret the data for us.
This is done by transforming it to the well-known text (WKT) representation defined in the [OpenGIS® Coordinate Transformation Service Standard](https://www.ogc.org/standards/ct/), which in turn can be interpreted by the [PROJ](https://proj.org/) library.

We can for example use [`coordinates`](@ref PointClouds.coordinates(::LAS, ::Any)) to look at $(x, y, z)$ of the first point in the WGS 84 coordinates ([EPSG:4326](https://epsg.io/4326)) that we used for our initial query:

```jldoctest tutorial
julia> coordinates(las, 1; crs = "EPSG:4326")
(-77.04692505523937, 38.902938366348046, 57.99)
```

We see that these are indeed close to the coordinates of our query.


## Accessing & filtering points

If we do not want to work with the full set of 16M points, we can look at a subset of those points:

```jldoctest tutorial
julia> subset = las[1:10000]
10,000-point LAZ (v1.2, PDRF 1, 01 Jun 2015)
  Source ID     => 65535
  Project ID    => AEB2BAA1-2BEF-41FC-B9BB-BDA288E8D77B
  System ID     => ""
  Software ID   => "GeoCue LAS Updater"
  X-Coordinates => 322500.0 … 322552.47000000003
  Y-Coordinates => 4.30797428e6 … 4.30799999e6
  Z-Coordinates => 15.8 … 723.47
  Return-Counts => [1 => 9,068, 2 => 906, 3 => 26]
  Extra Data    => [0x00, 0x00, 0xdd, 0xcc]
  Variable-Length Records
    => LASF_Projection[34735] "GeoTiff Projection Keys" (200 bytes)
    => LASF_Projection[34736] "GeoTiff double parameters" (80 bytes)
    => LASF_Projection[34737] "GeoTiff ASCII parameters" (217 bytes)
```

We can see that the header fields with the coordinate ranges and return counts have been updated.
We can compute further statistics by looping over the points:

```jldoctest tutorial
julia> cls = Dict()
Dict{Any, Any}()

julia> foreach(c -> cls[c] = get(cls, c, 0) + 1, classification(Int, pt) for pt in subset);

julia> sort(collect(cls))
4-element Vector{Pair{Any, Any}}:
  1 => 2401
  2 => 1394
 17 => 4285
 18 => 1920
```

We see that this point sample contains points marked as *unclassified* (1) and *ground* (2) according to the [ASPRS standard point classes](@ref PointClouds.classification), plus a large amount of points with class 17 and 18. These classes were later defined as *bridge deck* (17), and *high noise* (18) for the PDRFs 6–10, but since these points are stored in the PDRF 1, the use of these classes technically does not conform to the LAS specification and we cannot be sure of their interpretation without further information. If we dig up [the delivery report (PDF)](https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/metadata/Sandy_Supplemental_NCR_VA_MD_DC_QL2_LiDAR/MD-VA_Sandy-NCR_2014/reports/G13PD00816_Delivery_Lot_Summary_Report_Lot5_06262015.pdf) of this data collection, we see that these classes were used for *overlap default* (17) and *overlap ground* (18).

We could decide to remove all non-standard points from our sample:

```jldoctest tutorial
julia> subset = filter(pt -> classification(pt) <= 12, subset)
3,795-point LAZ (v1.2, PDRF 1, 01 Jun 2015)
  Source ID     => 65535
  Project ID    => AEB2BAA1-2BEF-41FC-B9BB-BDA288E8D77B
  System ID     => ""
  Software ID   => "GeoCue LAS Updater"
  X-Coordinates => 322500.0 … 322552.47000000003
  Y-Coordinates => 4.30797429e6 … 4.30799997e6
  Z-Coordinates => 15.8 … 723.47
  Return-Counts => [1 => 3,408, 2 => 372, 3 => 15]
  Extra Data    => [0x00, 0x00, 0xdd, 0xcc]
  Variable-Length Records
    => LASF_Projection[34735] "GeoTiff Projection Keys" (200 bytes)
    => LASF_Projection[34736] "GeoTiff double parameters" (80 bytes)
    => LASF_Projection[34737] "GeoTiff ASCII parameters" (217 bytes)
```


## In-memory processing

Let’s say we want to classify some of these unclassified points.
We can load the data we need for this into memory, as described in “[Loading point data](@ref)”:

```jldoctest tutorial
julia> pts = PointCloud(subset; attributes = (:class => classification, ));
```

This loads the coordinates plus the attributes we have specified:

```jldoctest tutorial
julia> propertynames(pts)
(:x, :y, :z, :class)
```

The coordinates are no longer encoded as integers and can be used directly:

```jldoctest tutorial
julia> typeof(pts.x)
Vector{Float64} (alias for Array{Float64, 1})

julia> pts.x[1:4]
4-element Vector{Float64}:
 322500.52
 322500.42
 322501.14
 322500.66000000003
```

We now try to update the classifications based on the five closest neighbors of each point.
For all unclassified points, we check whether a majority of the neighbors have the same class, and if this is the case we set the class to the result of this “neighborhood vote”:

```jldoctest tutorial
julia> count(==(1), pts.class)
2401

julia> pts.class = apply(pts, :class; neighbors = 5) do classes
         self, rest = Iterators.peel(classes)
         self == 1 || return self
         n, c = last(sort!([count(==(c), rest) => c for c in unique(rest)]))
         n >= 3 ? c : self
       end;

julia> count(==(1), pts.class)
2280
```

We see that there are only 2280 unclassified points left, as opposed to the original 2401.


## Updating & writing LAS data

Now we can combine the new classes with the original LAS data.
This still does not read the whole point-cloud data into memory and instead creates a lazy representation of the points that combines the new classification with the original data.

```jldoctest tutorial
julia> reclassified = update(subset, (classification = pts.class, ))
3,795-point LAZ (v1.2, PDRF 1, 01 Jun 2015)
  Source ID     => 65535
  Project ID    => AEB2BAA1-2BEF-41FC-B9BB-BDA288E8D77B
  System ID     => ""
  Software ID   => "GeoCue LAS Updater"
  X-Coordinates => 322500.0 … 322552.47000000003
  Y-Coordinates => 4.30797429e6 … 4.30799997e6
  Z-Coordinates => 15.8 … 723.47
  Return-Counts => [1 => 3,408, 2 => 372, 3 => 15]
  Extra Data    => [0x00, 0x00, 0xdd, 0xcc]
  Variable-Length Records
    => LASF_Projection[34735] "GeoTiff Projection Keys" (200 bytes)
    => LASF_Projection[34736] "GeoTiff double parameters" (80 bytes)
    => LASF_Projection[34737] "GeoTiff ASCII parameters" (217 bytes)
```

Finally, we can write this data to a new LAS file:

```jldoctest tutorial
julia> path = mktempdir();

julia> write(joinpath(path, "reclassified-subset.las"), reclassified)
```

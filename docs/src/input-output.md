# Working with LAS/LAZ data

```@meta
CurrentModule = PointClouds
```

Point-cloud data is usually distributed in the ASPRS “LAS” format or in its compressed “LAZ” variant.
PointClouds.jl reads and writes all current versions of these files (1.0 – 1.4) with close adherence to the specification.
The coordinate reference system (CRS) information is also parsed and can be used to transform or filter the data.

LAS files contain the some metadata fields in the header plus a list of point data records.
PointClouds.jl represents this data with [the `LAS` type](@ref "LAS data and its attributes"), which can load [points and their attributes](@ref "Point data records and their attributes") in a lazy manner to allow working with files that do not fit into memory.
The data can be [read from and written to a LAS/LAZ file](@ref "Reading & writing LAS/LAZ files"), [created from scratch](@ref "Creating new LAS data"), and [updated and filtered](@ref "Updating & filtering LAS data") in a lazy manner.

```@contents
Pages = ["input-output.md"]
Depth = 2:2
```

## LAS data and its attributes

```@docs
LAS
```

!!! note "LAS Specification"
    Details about the LAS format can be found in the specification documents: [1.0](https://www.asprs.org/wp-content/uploads/2010/12/asprs_las_format_v10.pdf), [1.1](https://www.asprs.org/wp-content/uploads/2010/12/asprs_las_format_v11.pdf), [1.2](https://www.asprs.org/wp-content/uploads/2010/12/asprs_las_format_v12.pdf), [1.3 R11](https://www.asprs.org/wp-content/uploads/2010/12/LAS_1_3_r11.pdf), [1.4 R15](https://www.asprs.org/wp-content/uploads/2019/07/LAS_1_4_r15.pdf) (PDFs, ongoing development on [GitHub](https://github.com/ASPRSorg/LAS/))


## Coordinate reference system (CRS)

The [`getcrs`](@ref) function reads the CRS data from a `LAS` file. Note that
functions such as [`coordinates`](@ref), [`filter`](@ref
Base.filter(::LAS)), and the [`PointCloud`](@ref)
constructor can also make use of this data without loading it explicitly.

```@docs
getcrs(::Type, ::LAS)
```

## Point data records and their attributes

The LAS format stores point in one of eleven different Point Data Record
Formats (PDRFs), which are numbered from 0 through 10 (as of LAS 1.4). Each
PDRF includes a slightly different set attributes such as GPS time or color
information. PDRFs 0–1 (defined since LAS 1.0), 2–3 (defined in LAS 1.2) and
4–5 (defined in LAS 1.3) are considered legacy formats that may be removed in
future versions of the LAS standard. PDRFs 6–10 were introduced in LAS 1.4.

In PointClouds.jl, LAS points are represented as [`PointRecord`](@ref)s. Use
`Base.eltype` to obtain the point record type of a `LAS`. The point attribute
functions listed below can be called on individual point records or on a LAS
with one or multiple indices.

```@docs
PointRecord
```

### 3D Position

The LAS format stores coordinates for each point as 32-bit integers. To obtain
the actual coordinates, the integer coordinates have to be rescaled by a global
offset and scale factor that is defined in the LAS header.

```@docs
coordinates(::Type{<:Integer}, ::PointRecord)
coordinates(::LAS, ::Any)
coordinates(::LAS)
```

### Color information

```@docs
color_channels
```

### Time information

```@docs
gps_time
```

### Laser pulse return

```@docs
intensity
return_number
return_count
waveform_packet
```

### Scanner & flight path attributes

```@docs
scan_angle
is_left_to_right
is_right_to_left
is_edge_of_line
scanner_channel
source_id
```

### Classification attributes

```@docs
classification
is_key_point
is_overlap
is_synthetic
is_withheld
```

### Custom attributes

The LAS format has two mechanisms to add additional attributes to all points.
The first one is the “[user data](@ref user_data)” byte that is included in all
PRDFs and may contain any data the producer of the file wishes to add. The
second one is the “[extra bytes](@ref extra_bytes)” section that can be used to
add an arbitrary number of bytes at the end of each point.

```@docs
user_data
extra_bytes
```

## Reading & writing LAS/LAZ files

To read a LAS/LAZ file, use
[`Base.read`](https://docs.julialang.org/en/v1/base/io-network/#Base.read):

```@docs
Base.read(::Base.IO, ::Type{LAS})
```

Alternatively, you can also use the `LAS` constructor:

```@docs
LAS(::Base.IO)
```


To write point-cloud data to a new LAS/LAZ file, use
[`Base.write`](https://docs.julialang.org/en/v1/base/io-network/#Base.write):

```@docs
Base.write(::Base.IO, ::LAS)
```

## Creating new LAS data

```@docs
LAS(::Type{<:PointRecord}, ::NamedTuple)
```

## Updating & filtering LAS data

```@docs
update(::LAS, ::NamedTuple)
update!(::LAS, ::NamedTuple)
```

```@docs
filter(::LAS)
filter!(::LAS)
```

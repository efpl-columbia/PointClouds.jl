# Point Cloud Processing

```@meta
CurrentModule = PointClouds
```

Point cloud processing usually involves a number of steps which use the available point attributes to compute new attributes and eventually produce some derived data about the physical environment.
PointClouds.jl includes the `PointCloud` struct for this purpose.
It stores (a subset of) the original point attributes in a tabular format for in-memory processing and provides functionality to add/update/remove columns (i.e. point attributes) and to filter rows (i.e. points).

```@contents
Pages = ["point-processing.md"]
Depth = 2:2
```

## Loading point data

To load point data into memory, use the `PointCloud` constructor:

```@docs
PointCloud
```

## Coordinate reference system (CRS)

The [`getcrs`](@ref) function reads the CRS data from a `PointCloud`. Note that
functions such as [`coordinates`](@ref), [`filter`](@ref
Base.filter(::Function, ::LAS, ::Any)), and the `PointCloud` constructor can
also make use of this data without loading it explicitly.

```@docs
getcrs(::PointCloud)
```

Coordinates can be transformed [when loading point data](@ref PointCloud) or
with the [`transform`](@ref transform(::PointCloud)) function.

```julia
pts = transform(pts, crs = "EPSG:32618") # UTM 18N
```

This always produces a new variable, since the CRS is an immutable property of
the [`PointCloud`](@ref). Note that if the data previously had no CRS, the CRS
is set to the target one but the coordinates are left untouched.

```@docs
transform(::PointCloud)
```

## Updating point attributes

Point attributes can be created, accessed, and updated using “property” syntax.
The names of point attributes have no special meaning, except for `x`, `y`, and
`z`, which are expected to represent the point coordinates. Some point
processing functions may also attribute meaning to other names (e.g.
[`neighbors!`](@ref)).

```jldoctest; setup = :(using PointClouds)
julia> pts = PointCloud((x = 0:2, y = 1:3));

julia> pts.x .+= 1
3-element Vector{Float64}:
 1.0
 2.0
 3.0

julia> pts.distance_from_origin = sqrt.(pts.x.^2 .+ pts.y.^2)
3-element Vector{Float64}:
 1.4142135623730951
 2.8284271247461903
 4.242640687119285

julia> keys(pts)
(:x, :y, :distance_from_origin)

julia> delete!(pts, :distance_from_origin);
```

Computing new attributes generally involves looping over the existing
attributes. This can be done with the built-in
[`map`](https://docs.julialang.org/en/v1/base/collections/#Base.map) or
[`broadcast`](https://docs.julialang.org/en/v1/base/arrays/#Base.Broadcast.broadcast)
functions, e.g. `map((x, y) -> x^2 + y^2, pts.x, pts.y)` or using the [dot
syntax](https://docs.julialang.org/en/v1/manual/functions/#man-vectorized) as
in the example above.

### Parallel point processing

PointClouds.jl also includes the [`apply`](@ref) function, which is similar to
`map` but runs in parallel using multi-threading and has some additional
functionality specific to point-cloud processing.

```@docs
apply
```

### Type stability

!!! warning
    The `PointCloud` type contains no static information about the element type
    of attributes. Performance-sensitive point processing should therefore be
    done by a [“kernel
    function”](https://docs.julialang.org/en/v1/manual/performance-tips/#kernel-functions)
    that takes individual attribute vectors as its argument. This is the case
    when using `map`, `broadcast`, or [`apply`](@ref).

Coordinates can also be accessed with the [`coordinates`](@ref
PointClouds.coordinates(::PointCloud, ::Any)) function, which is type-stable:

```@docs
coordinates(::PointCloud, ::Any)
```

## Filtering points

The points in a `PointCloud` can be reduced to a subset with the
`filter`/`filter!` functions. Alternatively, a subset can be selected through
indexing (`keepat!` for in-place modification).

```@docs
filter(::Function, ::PointCloud, ::Vararg)
filter!(::Function, ::PointCloud, ::Vararg)
```

## Neighborhood-based processing

Several point-cloud processing algorithms depend on the neighborhood of each
point. The [`neighbors`](@ref) function computes the indices of neighboring
points, which can then be used in further processing steps, e.g. when using
[`apply`](@ref):

```jldoctest; setup = :(using PointClouds)
julia> pts = PointCloud((x = rand(16), y = rand(16), z = rand(16)));

julia> neighbors!(pts, 4);

julia> pts.zmin = apply(minimum, pts, :z; neighbors = true);

julia> pts.zavg = apply(zs -> sum(zs) / length(zs), pts, :z; neighbors = true);
```

```@docs
neighbors
neighbors!
```

## Rasterization

Use [`rasterize`](@ref) to compute the mapping of points to a raster/voxel grid.

```@docs
rasterize
```

Mapping a function over the resulting `RasterizedPointCloud` applies it to each pixel/voxel, passing the list of points to the function.

```julia
zavg = map(r.z) do zs
    isempty(zs) ? missing : sum(zs) / length(zs)
end
```

This can also be used to combine raster and point data.

```julia
zstd = map(r.z, zavg) do zs, zavg
    length(zs) < 2 ? missing : sum(z -> abs2(z - zavg), zs) / (length(zs) - 1)
end
```

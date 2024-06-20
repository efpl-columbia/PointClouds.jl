#=
The PointCloud stores point-cloud data as “columns”, in struct-of-array
style. Each column contains the values of one field for all of the points and
has a uniform type, e.g. Float64, or perhaps a Union{Float64,Missing}. However,
the type information of the columns is not part of the point-cloud type in
order to allow adding and removing columns. This means that accessing data
within a function that takes the PointCloud as an argument is slow.
Instead, such a function should fetch all the columns required for a
computation and pass them to an inner function that does the actual work. The
inner function then should have static access to the element types of the
columns.
=#
struct PointCloud <: AbstractPointCloud
  data::DataFrames.DataFrame
  crs::Any
end

# accessors (getproperty is overloaded so pts.data does not work)
getdata(pts::PointCloud) = getfield(pts, :data) # not exported

"""
    getcrs(pts::PointCloud)
"""
getcrs(pts::PointCloud) = getfield(pts, :crs) # exported

# equality testing
function Base.:(==)(pts1::PointCloud, pts2::PointCloud)
  getdata(pts1) == getdata(pts2) && getcrs(pts1) == getcrs(pts2)
end

# dictionary-style indexing refer to attributes (“columns”)
const AttributeName = Union{Symbol,AbstractString}
Base.keys(pts::PointCloud) = Tuple(propertynames(getdata(pts)))
Base.haskey(pts::PointCloud, key::AttributeName) = hasproperty(getdata(pts), key)
Base.getindex(pts::PointCloud, key::AttributeName) = getproperty(getdata(pts), key)
function Base.setindex!(pts::PointCloud, val::AbstractVector, key::AttributeName)
  setproperty!(getdata(pts), key, val)
end
Base.propertynames(pts::PointCloud) = keys(pts)
Base.hasproperty(pts::PointCloud, key::Symbol) = haskey(pts, key)
Base.getproperty(pts::PointCloud, key::Symbol) = pts[key]
Base.setproperty!(pts::PointCloud, key::Symbol, val::AbstractVector) = pts[key] = val
Base.names(pts::PointCloud) = String.(keys(pts))
function Base.delete!(pts::PointCloud, key::Symbol)
  (DataFrames.select!(getdata(pts), DataFrames.Not(key)); pts)
end

# vector-style indices refer to points (“rows”)
Base.length(pts::PointCloud) = size(getdata(pts), 1)
Base.firstindex(pts::PointCloud) = firstindex(getdata(pts), 1)
Base.lastindex(pts::PointCloud) = lastindex(getdata(pts), 1)
Base.eachindex(pts::PointCloud) = firstindex(pts):lastindex(pts)

# indexing by a single number returns a named tuple (TODO: reconsider)
Base.getindex(pts::PointCloud, ind::Number) = NamedTuple(getdata(pts)[ind, :])

# indexing by range etc. returns a new point cloud
Base.getindex(pts::PointCloud, inds) = PointCloud(getdata(pts)[inds, :], getcrs(pts))

function PointCloud(
  input::NamedTuple;
  crs = nothing,
  #extent = nothing, # TODO: support bounding box
  #filter = nothing, # TODO: support filter
  #tol = 1e-6,
)
  function normalize(k, v)
    k => (k in (:x, :y, :z) ? collect(Float64, v) : v isa Tuple ? collect(v) : v)
  end
  data = [normalize(k, v) for (k, v) in pairs(input)]
  PointCloud(DataFrames.DataFrame(data), crs)
end

normalize_input(las::LAS) = [las]
normalize_input(input) = [LAS(input)]
normalize_input(inputs::AbstractArray) = [LAS(i) for i in inputs]
normalize_input(inputs::Tuple) = [LAS(i) for i in inputs]

normalize_attrs(attr) = normalize_attrs(tuple(attr)) # allow single value
normalize_attrs(attrs::AbstractArray) = normalize_attrs(Tuple(attrs))
normalize_attrs(attrs::NamedTuple) = Tuple(pairs(attrs))
normalize_attrs(attrs::Tuple) = map(a -> a isa Pair ? a : nameof(a) => a, attrs)

init_coords(inputs, coords) = map(c -> c => Float64[], coords)
function init_attrs(inputs, attrs)
  pdrfs = eltype.(inputs)
  map(attrs) do (name, func)
    Ts = Union{vcat(map(T -> Base.return_types(func, Tuple{T}), pdrfs)...)...}
    name => Ts == Bool ? BitVector() : Ts[]
  end
end

"""
    PointCloud(input; kws...)

Load (a subset of) point data into memory for processing. The data is stored in
“columnar format”, where each point attribute (coordinates, intensity, etc.)
forms a column with one entry (row) per point. Attributes can be
added/updated/removed in further processing steps.

The `input` can be one or multiple (passed as tuple/array) [`LAS`](@ref)
values, or values that can be passed to [`read(input, LAS)`](@ref
Base.read(::IO, ::LAS)) such as the path to a LAS/LAZ file. Alternatively, a
`NamedTuple` of `Vector`s can be passed, where the `x`, `y`, and `z`-names are
interpreted as coordinates and all the other names as additional attributes.

# Keywords

  - `attributes`: Additional attributes that are included for each point.
    Attributes are specified as a tuple/array of functions that are applied to
    each point to compute the attribute. By default, the name of the function is
    used as attribute name, but a manual name can be specified by passing a
    `Pair{Symbol,Function}` instead. The attributes can also be defined with a
    `NamedTuple`, where the keys are the attribute names and the values are the
    functions. Default: `()`.
  - `coordinates`: Subset of coordinates to load, e.g. `(:x, :y)` if the vertical
    coordinates are not required. Default: `(:x, :y, :z)`.
  - `crs`: Coordinate reference system (CRS) that the x/y/z-coordinates should be
    transformed to, specified as any string understood by the [PROJ
    library](https://proj.org/en/9.4/usage/quickstart.html). Default: CRS of the
    first input.
  - `x` or `lon`: A tuple `(xmin, xmax)` with the minimum and maximum value of
    the x-coordinate range that should be retained, in the CRS of the output.
  - `y` or `lat`: A tuple `(ymin, ymax)` with the minimum and maximum value of
    the y-coordinate range that should be retained, in the CRS of the output.
  - `z`: A tuple `(zmin, zmax)` with the minimum and maximum value of the
    z-coordinate range that should be retained, in the CRS of the output.
  - `filter`: Predicate function that is called on each point to exclude points
    for which the `filter` function returns `false`.

# Examples

    PointCloud(las; attributes = (intensity, :t => gps_time))
    PointCloud(las; attributes = (i = intensity, t = gps_time))
    PointCloud(las; crs = "EPSG:4326", extent = ((-73.97, 40.80), (-73.95, 40.82)))
"""
function PointCloud(
  input;
  coordinates = (:x, :y, :z),
  attributes = (),
  extent = nothing,
  filter = nothing,
  crs = nothing,
  tol = 1e-6,
)

  # normalize input data
  inputs = normalize_input(input)
  attrs = normalize_attrs(attributes)
  crs = isnothing(crs) ? getcrs(String, first(inputs)) : crs

  # TODO: make sure attributes cannot override coordinates
  data = (; init_coords(input, coordinates)..., init_attrs(inputs, attrs)...)

  for input in inputs
    coords = PointClouds.coordinates(input; crs = crs)
    load_points!(data, input, coords, attrs, extent, filter, tol)
  end

  PointCloud(DataFrames.DataFrame(data), crs)
end

function load_points!(fields, input, coords, attrs, extent, filter, tol)
  for point in input
    x, y, z = coords(point)

    # check whether we are skipping the current point
    extent_contains(extent, (x, y), tol) || continue
    isnothing(filter) || filter(point) || continue

    # start pushing data once the skip-checks have passed
    haskey(fields, :x) && push!(fields.x, x)
    haskey(fields, :y) && push!(fields.y, y)
    haskey(fields, :z) && push!(fields.z, z)

    for (name, attr) in attrs
      push!(fields[name], attr(point))
    end
  end
end

extent_contains(::Nothing, _, _) = true

function extent_contains(extent, coords, tol)
  for ind in 1:length(coords)
    first(extent)[ind] - tol <= coords[ind] <= last(extent)[ind] + tol || return false
  end
  true
end

"""
    coordinates(p::PointCloud, index; crs)

Obtain the x-, y-, and z-coordinate of the `index`-th point as a tuple of
`Float64`s. The coordinate reference system (CRS) of the `PointCloud` is used
unless a different crs is specified. To obtain coordinates of multiple points,
pass a range of indices or `:` as the `index` argument.

Provide the `crs` keyword argument to transform the coordinates to a new CRS
instead of the current CRS of the `PointCloud`.
"""
coordinates(pts::PointCloud, inds; crs = nothing) = error("Not yet implemented")

"""
    transform(p::PointCloud; crs)

Transform the coordinates of a `PointCloud` to a new coordinate reference
system (CRS). If there is no current CRS, the coordinates remain unchanged but
the new CRS is added to the `PointCloud`.

The required keyword argument `crs` can be any string understood by the [PROJ
library](https://proj.org/en/9.4/usage/quickstart.html). If set to `nothing`,
the CRS is removed.
"""
transform(pts::PointCloud; kws...) = error("Not yet implemented")

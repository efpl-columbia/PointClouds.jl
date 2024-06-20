"""
    filter([f::Function], las::LAS; kws...)

Create a copy of a `LAS` that excludes point which do not meet the specified
filter criteria. Filtering can be done with a function `f` that returns `false`
for each `PointRecord` that should be discarded or with the keyword arguments
to filter by extent (but not both). Note that you can also indexing (and
`keepat!` for in-place modification) to filter a point-cloud, especially in
combination with logical indexing.

# Keywords

  - `x` or `lon`: A tuple `(xmin, xmax)` with the minimum and maximum value of
    the x-coordinate range that should be retained.
  - `y` or `lat`: A tuple `(ymin, ymax)` with the minimum and maximum value of
    the y-coordinate range that should be retained.
  - `z`: A tuple `(zmin, zmax)` with the minimum and maximum value of the
    z-coordinate range that should be retained.
  - `crs`: The coordinate reference system in which the extent should be applied.
    Set to the CRS of the `LAS` by default.

See also: [`filter!`](@ref Base.filter!(::Function, ::LAS, ::Any))
"""
Base.filter(las::LAS; kws...) = filter(gen_check_extent(las; kws...), las)

"""
    filter!([f::Function], las::LAS; kws...)

Remove points that do not meet the specified filter criteria from a `LAS`. This
is only supported if the point records of the `LAS` have been loaded into
memory or if they have already been filtered.
See [`filter`](@ref Base.filter(::Function, ::LAS, ::Any)) for details.
"""
Base.filter!(las::LAS; kws...) = filter!(gen_check_extent(las; kws...), las)

# generates a function that checks whether a point is within the extent
function gen_check_extent(las; crs = nothing, tol = nothing, kws...)
  getcoords = coordinates(las; crs = crs)
  tol = tol isa Tuple ? tol : (tol, tol, tol)
  extent = normalize_extent_kws(; kws...)
  pt -> begin
    coords = getcoords(pt)
    within_extent(coords[1], extent[1], tol[1]) || return false
    within_extent(coords[2], extent[2], tol[2]) || return false
    within_extent(coords[3], extent[3], tol[3]) || return false
    true # point is within extent
  end
end

function normalize_extent_kws(;
  lat = nothing,
  lon = nothing,
  x = nothing,
  y = nothing,
  z = nothing,
)
  isnothing(x) ||
    isnothing(lon) ||
    throw(ArgumentError("`x` and `lon` are equivalent, only provide one of them"))
  isnothing(y) ||
    isnothing(lat) ||
    throw(ArgumentError("`y` and `lat` are equivalent, only provide one of them"))
  isnothing(x) ? lon : x, isnothing(y) ? lat : y, z
end

"""
    filter([f::Function], pts::PointCloud, attrs...; kws...)

Create a copy of a `PointCloud` that excludes point which do not meet the
specified filter criteria. Filtering can be done with a function `f` that
returns `false` for each point that should be discarded, taking the attributes
specified with `attrs` as arguments. Alternatively, points can be filtered by
extent using the keyword arguments.

Note that you can also indexing (and `keepat!` for in-place modification) to
filter a point-cloud, especially in combination with logical indexing.

# Keywords

  - `x` or `lon`: A tuple `(xmin, xmax)` with the minimum and maximum value of
    the x-coordinate range that should be retained.
  - `y` or `lat`: A tuple `(ymin, ymax)` with the minimum and maximum value of
    the y-coordinate range that should be retained.
  - `z`: A tuple `(zmin, zmax)` with the minimum and maximum value of the
    z-coordinate range that should be retained.
  - `crs`: The coordinate reference system in which the extent should be applied.
    Set to the CRS of the `PointCloud` by default.

See also: [`filter!`](@ref Base.filter!(::Function, ::PointCloud, ::Vararg))
"""
Base.filter(fn::Function, pts::PointCloud, cols...; kws...) =
  Base.filter(pts; predicate = cols => fn, kws...)

"""
    filter!([f::Function], pts::PointCloud, attrs...; kws...)

Remove points that do not meet the specified filter criteria from a
`PointCloud`. See [`filter`](@ref Base.filter(::Function, ::PointCloud,
::Vararg)) for details.
"""
Base.filter!(fn::Function, pts::PointCloud, cols...; kws...) =
  Base.filter!(pts; predicate = cols => fn, kws...)

function Base.filter(pts::PointCloud, sel::BitVector = trues(length(pts)); kws...)
  getindex(pts, apply_filters!(sel, pts; kws...))
end

function Base.filter!(pts::PointCloud, sel::BitVector = trues(length(pts)); kws...)
  keepat!(pts, apply_filters!(sel, pts; kws...))
end

function apply_filters!(
  sel::BitVector,
  pts::PointCloud;
  # filter by extent
  lat = nothing,
  lon = nothing,
  x = nothing,
  y = nothing,
  z = nothing,

  # filter by predicate
  predicate = nothing,

  # filter by index
  length = nothing,
  start = nothing,
  step = nothing,
  stop = nothing,

  # different CRS for extent/predicate filtering
  crs = nothing,
)

  # verify that there are no duplicate arguments
  isnothing(x) ||
    isnothing(lon) ||
    throw(ArgumentError("`x` and `lon` are equivalent, only provide one of them"))
  isnothing(y) ||
    isnothing(lat) ||
    throw(ArgumentError("`y` and `lat` are equivalent, only provide one of them"))

  # filter first by extent, then by predicate function, then by indexing
  apply_extents!(sel, pts, isnothing(x) ? lon : x, isnothing(y) ? lat : y, z, crs)
  apply_predicate!(sel, pts, predicate, crs)
  apply_subrange!(sel, length, start, step, stop)

  sel
end

apply_predicate!(sel::BitVector, ::PointCloud, ::Nothing, _) = sel

function apply_predicate!(sel::BitVector, pts::PointCloud, predicate::Pair, crs)
  cols, fn = predicate
  @assert allunique(cols)

  # only transform coordinates when they are required
  if isnothing(crs) || !any(col in (:x, :y, :z) for col in cols)
    return apply_predicate_parallel!(fn, sel, map(col -> pts[col], cols))
  end

  # wrap function with coordinate transform
  #allcols = (cols..., filter(!in(cols), (:x, :y, :z))...)
  transform = Proj.Transformation(getcrs(pts), crs; always_xy = true)
  allcols = (:x, :y, :z, filter(!in((:x, :y, :z)), cols)...)
  inds = map(col -> findfirst(==(col), allcols), cols)
  fn = transformed(fn, transform, Val(inds))

  # the Proj transform is not thread-safe, so we loop over the points in series
  # TODO: use separate context per thread for thread-safe projections
  # note: we need `invokelatest` so it “sees” the `fn` that was just defined
  apply_predicate_serial!(fn, sel, map(col -> pts[col], allcols))
end

function transformed(fn, transform, ::Val{inds}) where {inds}
  (args...) -> let
    args = (transform(args[1:3]...)..., args[4:end]...)
    fn(map(ind -> args[ind], inds)...)
  end
end

function apply_predicate_serial!(fn::F, sel::BitVector, cols) where {F<:Function}
  # note: the type parameter is needed to trigger specialization on the function
  for ind in eachindex(sel, cols...)
    @inbounds sel[ind] || continue # skip points that are already excluded
    args = @inbounds getindex.(cols, ind)
    keep = fn(args...)
    @inbounds sel[ind] = keep
  end
  sel
end

function apply_predicate_parallel!(fn::F, sel::BitVector, cols) where {F<:Function}
  # note: the type parameter is needed to trigger specialization on the function
  Polyester.@batch for ind in eachindex(sel, cols...)
    @inbounds sel[ind] || continue # skip points that are already excluded
    args = @inbounds getindex.(cols, ind)
    keep = fn(args...)
    @inbounds sel[ind] = keep
  end
  sel
end

function apply_extents!(sel::BitVector, pts, x, y, z, crs)
  apply_predicate!(sel, pts, (:x, :y, :z) => within_extents(x, y, z), crs)
end

function within_extents(xext, yext, zext)
  xtol, ytol, ztol = extent_tolerance.((xext, yext, zext))
  (x, y, z) -> begin
    within_extent(x, xext, xtol) || return false
    within_extent(y, yext, ytol) || return false
    within_extent(z, zext, ztol) || return false
    true # point is within extent
  end
end

within_extent(_, ::Nothing, _) = true
within_extent(val, ext::Tuple{Number,Number}, ::Nothing) = ext[1] <= val <= ext[2]
within_extent(val, ext::Tuple{Number,Number}, tol) = ext[1] - tol <= val <= ext[2] + tol

extent_tolerance(::Nothing) = nothing
extent_tolerance(ext::Tuple) = ((min, max) = extrema(ext); (max - min) * eps())

function apply_subrange!(sel, length, start, step, stop)
  isnothing(start) || @assert start >= 0
  isnothing(stop) || @assert stop >= 0
  isnothing(length) || @assert length >= 0
  n = sum(sel)
  r = subrange(1:n, length, start, step, stop)
  Base.step(r) >= 0 ||
    throw(ArgumentError("`step` cannot be negative (use `reverse!` instead)"))
  r == 1:n || apply_subrange!(sel, sort(r))
  sel
end

function apply_subrange!(sel::BitVector, r)
  r = sort(r)
  ir = 1
  for ind in eachindex(sel)
    sel[ind] || continue
    sel[ind] = ir in r
    ir += 1
  end
  sel
end

# allow overriding
function subrange(inds, length, start, step, stop)
  inds[range(; length = length, start = start, step = step, stop = stop)]
end
subrange(inds, ::Nothing, start::Integer, ::Nothing, ::Nothing) = inds[start:end]
subrange(inds, ::Nothing, ::Nothing, step::Integer, ::Nothing) = inds[begin:step:end]
subrange(inds, ::Nothing, start::Integer, step::Integer, ::Nothing) = inds[start:step:end]
subrange(inds, ::Nothing, ::Nothing, ::Nothing, ::Nothing) = inds
function subrange(inds, length::Integer, ::Nothing, step::Integer, ::Nothing)
  inds[begin:step:(begin+step*(length-1))]
end
subrange(inds, ::Nothing, ::Nothing, step::Integer, stop::Integer) = inds[begin:step:stop]
function subrange(inds, length::Integer, start::Integer, ::Nothing, stop::Integer)
  step = div(stop - start, length - 1)
  iszero(step) && throw(ArgumentError("step cannot be zero"))
  stop = start + step * (length - 1)
  inds[start:step:stop]
end

struct RasterizedPointCloud{N}
  data::DataFrames.DataFrame
  point_indices::Vector{Int}
  offsets::Vector{Int}
  dims::NTuple{N,Int}
  extent::NTuple{2,NTuple{N,Float64}}
  crs::Any
end

struct PointCloudField{N,V}
  data::V
  point_indices::Vector{Int}
  offsets::Vector{Int}
  dims::NTuple{N,Int}
end

Base.getproperty(r::RasterizedPointCloud, f::Symbol) = getindex(r, f)

function Base.getindex(r::RasterizedPointCloud, f::AttributeName)
  data = getfield(r, :data)[!, f]
  point_indices = getfield(r, :point_indices)
  offsets = getfield(r, :offsets)
  dims = getfield(r, :dims)
  PointCloudField{length(dims),typeof(data)}(data, point_indices, offsets, dims)
end

Base.size(c::RasterizedPointCloud) = c.dims

Base.length(c::PointCloudField) = prod(c.dims)
Base.size(c::PointCloudField) = c.dims
Base.eltype(c::PointCloudField) = typeof(c[1])

function Base.getindex(c::PointCloudField, ind::Integer)
  indmin = ind == 1 ? 1 : c.offsets[ind-1] + 1
  indmax = c.offsets[ind]
  view(c.data, view(c.point_indices, indmin:indmax))
end

function Base.iterate(c::PointCloudField, ind::Integer = 1)
  ind <= length(c) || return nothing
  (c[ind], ind + 1)
end

Base.IteratorSize(::Type{<:PointCloudField{N}}) where {N} = Base.HasShape{N}()

"""
    rasterize(p::PointCloud, dims; kws...)

Rasterize points in a `PointCloud` by assigning them to gridded locations
within a target area. The raster has dimensions `dims` (given as a tuple of
integers), is aligned with the axes of the x-/y-coordinates, and spans the full
bounding box of the points, unless the extent is narrowed with keyword
arguments. By default, each raster location is mapped to the points that lie
within its “pixel area”, unless the `radius` or `neighbors` keyword arguments
are specified. Currently, only 2D rasterization is supported.

Note that with the default “pixel area” method, each point gets assigned to
exactly one raster location if it lies within the bounds of the raster. With
the `radius` and `neighbors` methods, points may get assigned to multiple or
zero raster locations. Furthermore, only the `neighbors` method guarantees that
each raster location has points assigned to it; the other methods may produce
empty pixels.

# Keywords

  - `x` or `lon`: A tuple `(xmin, xmax)` with the minimum and maximum value of
    the x-coordinate range that should be divided into `dims[1]` intervals.
  - `y` or `lat`: A tuple `(ymin, ymax)` with the minimum and maximum value of
    the y-coordinate range that should be divided into `dims[2]` intervals.
  - `radius`: Assign all points within a distance of `radius` from the pixel
    center to that raster location. The unit of `radius` is the same as the
    x-/y-coordinates. Note that points may get assigned to multiple or zero
    raster locations.
  - `neighbors`: Assign a specific number `neighbors` of points to each raster
    location based on which ones are closest to the pixel center.
"""
function rasterize(
  pts::PointCloud,
  dims;
  extent = boundingbox(pts),
  radius = nothing,
  neighbors = nothing,
)
  isnothing(radius) || return rasterize_radius(pts, dims, extent, radius)
  isnothing(neighbors) || return rasterize_neighbors(pts, dims, extent, neighbors)

  # unpack bounding box corners
  # TODO: support 3-dimensional boxes
  ndims = length(dims)
  extmin, extmax = extent
  @assert length(extmin) == length(extmax) == ndims == 2

  # compute origin and spacing in local coordinates
  spacing = (extmax .- extmin) ./ dims
  origin = extmin .- spacing

  # determine raster index for each point
  pixel_indices = map(zip(pts.x, pts.y)) do coord
    i, j = div.(coord .- origin, spacing)
    if 1 <= i <= dims[1] && 1 <= j <= dims[2]
      Int(i + (j - 1) * dims[1])
    else
      zero(Int) # points will be skipped
    end
  end
  @assert length(pixel_indices) == length(pts)

  # compute offsets of pixels into point arrays
  offsets = zeros(Int, prod(dims))
  for ipx in pixel_indices
    iszero(ipx) && continue
    offsets[ipx] += 1
  end
  npt = offsets[end] # count for last pixel
  exclusive_prefix_sum!(offsets)
  npt += offsets[end] # count for all other pixels

  # build array of indices in pixel order
  point_indices = zeros(Int, npt)
  for (ipt, ipx) in enumerate(pixel_indices)
    iszero(ipx) && continue
    offsets[ipx] += 1
    point_indices[offsets[ipx]] = ipt
  end
  @assert offsets[end] == npt
  @assert !any(iszero, point_indices)

  RasterizedPointCloud{2}(
    getfield(pts, :data),
    point_indices,
    offsets,
    dims,
    extent,
    getfield(pts, :crs),
  )
end

function rasterize_radius(pts::PointCloud, dims, extent, radius; tol = 1e-9 * radius)
  # unpack bounding box corners
  # TODO: support 3-dimensional boxes
  ndims = length(dims)
  extmin, extmax = extent
  @assert length(extmin) == length(extmax) == ndims == 2

  # compute origin and spacing in local coordinates, such that cell centers are at (origin + spacing * index)
  spacing = (extmax .- extmin) ./ dims
  origin = extmin .- spacing ./ 2

  # translate radius into “search footprint” in raster pixels
  # assuming that center may have been shifted by half a pixel
  nx, ny = (radius + tol) ./ spacing

  # determine “exact” raster index for each point
  pixel_indices = map(zip(pts.x, pts.y)) do coord
    ipt, jpt = (coord .- origin) ./ spacing # (i, j)
    inds = Int[]
    for j in ceil(Int, jpt - ny):floor(Int, jpt + ny)
      1 <= j <= dims[2] || continue
      for i in ceil(Int, ipt - nx):floor(Int, ipt + nx)
        1 <= i <= dims[1] || continue
        if ((ipt - i) * spacing[1])^2 + ((j - jpt) * spacing[2])^2 <= radius^2
          push!(inds, i + (j - 1) * dims[1])
        end
      end
    end
    inds
  end
  @assert length(pixel_indices) == length(pts)

  # compute offsets of pixels into point arrays
  offsets = zeros(Int, prod(dims))
  for ipxs in pixel_indices
    for ipx in ipxs
      offsets[ipx] += 1
    end
  end
  npt = offsets[end] # count for last pixel
  exclusive_prefix_sum!(offsets)
  npt += offsets[end] # count for all other pixels

  # build array of indices in pixel order
  point_indices = zeros(Int, npt)
  for (ipt, ipxs) in enumerate(pixel_indices)
    for ipx in ipxs
      offsets[ipx] += 1
      point_indices[offsets[ipx]] = ipt
    end
  end
  @assert offsets[end] == npt
  @assert !any(iszero, point_indices)

  RasterizedPointCloud{2}(
    getfield(pts, :data),
    point_indices,
    offsets,
    dims,
    extent,
    getfield(pts, :crs),
  )
end

function rasterize_neighbors(pts::PointCloud, dims, extent, neighbors; sort = true)
  # unpack bounding box corners
  # TODO: support 3-dimensional boxes
  ndims = length(dims)
  extmin, extmax = extent
  @assert length(extmin) == length(extmax) == ndims == 2

  # compute origin and spacing in local coordinates, such that cell centers are at (origin + spacing * index)
  spacing = (extmax .- extmin) ./ dims
  origin = extmin .- spacing ./ 2

  # prepare nearest neighbor
  pvec = NearestNeighbors.SVector.(zip(pts.x, pts.y))
  tree = NearestNeighbors.KDTree(pvec; reorder = false)
  offsets = (1:prod(dims)) .* neighbors

  # build array of indices in pixel order
  point_indices = zeros(Int, last(offsets))
  for jpx in 1:dims[2], ipx in 1:dims[1]
    offset = (ipx - 1) + (jpx - 1) * dims[1]
    inds = (1:neighbors) .+ neighbors * offset
    pt = NearestNeighbors.SVector(origin .+ (ipx, jpx) .* spacing)
    point_indices[inds] .= NearestNeighbors.knn(tree, pt, neighbors, sort)[1]
  end
  @assert !any(iszero, point_indices)

  # TODO: store offsets as range instead of vector
  RasterizedPointCloud{2}(
    getfield(pts, :data),
    point_indices,
    collect(offsets),
    dims,
    extent,
    getfield(pts, :crs),
  )
end

function exclusive_prefix_sum!(arr)
  acc = zero(eltype(arr))
  for i in eachindex(arr)
    arr[i], acc = acc, acc + arr[i]
  end
  arr
end

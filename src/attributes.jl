module Attributes

export apply, neighbors, neighbors!

using NearestNeighbors: NearestNeighbors
using Polyester: Polyester
import ..PointCloud

"""
    apply(f::Function, [T], p::PointCloud, attrs...; kws...)

Apply a function `f` to the attributes `attrs` of each point in `p`. The
attribute names are passed as `Symbol`s and the function should take one
argument for each attribute name.

The element type of the output is determined automatically from the function
and the argument types. It can also be set with the `T` argument in case the
automatically determined type is too narrow or too wide.

# Keywords

  - `neighbors`: Apply function to the attribute of a point’s neighbors rather
    than its own, if set to `true` or to an integer `k`. The function `f`
    receives `AbstractVector`s with the attribute values of the neighbors in that
    case. The indices of the `k` nearest neighbors are read from `p.neighbors` if
    available (see [`neighbors`](@ref)/[`neighbors!`](@ref)). If `p.neighbors` is
    unavailable or contains fewer than `k` indices, the neighbor search is
    (re)run (without updating `p.neighbors`). Default: `false`
"""
function apply(fn::Function, pts::PointCloud, attrs...; neighbors = false)
  cols = getproperty.((pts,), attrs)

  # handle straightforward case without neighbors
  if neighbors == false # can be non-boolean
    T = Union{Base.return_types(fn, eltype.(cols))...}
    out = Vector{T}(undef, length(pts))
    return _map!(fn, out, cols)
  end

  # get array with neighbor indices
  if neighbors == true
    neighbors = pts.neighbors
  elseif neighbors isa Integer
    neighbors = Attributes.neighbors(pts, neighbors)
  end

  # for now, we guess the return type with full columns instead of views
  T = Union{Base.return_types(fn, typeof.(cols))...}
  out = Vector{T}(undef, length(pts))
  _map_neighbors!(fn, out, neighbors, cols)
end

function _map!(fn::F, output, inputs) where {F<:Function}
  # note: the type parameter is needed to trigger specialization on the function
  Polyester.@batch for ind in eachindex(output, inputs...)
    args = @inbounds getindex.(inputs, ind)
    out = fn(args...)
    @inbounds output[ind] = out
  end
  output
end

function _map_neighbors!(fn::F, output, neighbors, inputs) where {F}
  # note: the type parameter is needed to trigger specialization on the function
  Polyester.@batch for ind in eachindex(output, neighbors, inputs...)
    nbs = NearestNeighbors.SVector(ind, (@inbounds getindex(neighbors, ind))...)
    args = view.(inputs, (nbs,))
    out = fn(args...)
    @inbounds output[ind] = out
  end
  output
end

"""
    neighbors(p::PointCloud, k::Integer)

Obtain the indices of the `k` nearest neighbors of each point as a vector of vectors, where the inner vectors have a fixed length `k`.

See also: [`neighbors!`](@ref)
"""
function neighbors(p::PointCloud, k::Integer)
  pts = NearestNeighbors.SVector.(zip(p.x, p.y, p.z))
  tree = NearestNeighbors.KDTree(pts; reorder = false)
  nbs = Vector{NearestNeighbors.SVector{k,Int}}(undef, length(p))
  neighbors!(nbs, tree)
end

function neighbors!(nbs::Vector{NearestNeighbors.SVector{K,Int}}, tree) where {K}
  Polyester.@batch for ind in eachindex(tree.data, nbs)
    @inbounds pt = tree.data[ind]
    inds, _ = NearestNeighbors.knn(tree, pt, K + 1, true)
    inds = NearestNeighbors.SVector(Iterators.filter(!=(ind), inds)...)
    @inbounds nbs[ind] = inds
  end
  nbs
end

"""
    neighbors!(p::PointCloud, k::Integer)

Store the indices of the `k` nearest neighbors of each point in the `neighbors` attribute of the `PointCloud`.

See also: [`neighbors`](@ref)
"""
neighbors!(p::PointCloud, k::Integer) = (p.neighbors = neighbors(p, k); p)

end # module Attributes

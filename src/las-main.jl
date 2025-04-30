"""
`LAS` represents point-cloud data in the ASPRS “LAS” format, consisting of a
collection of [`PointRecord`](@ref)s as well as a number of global attributes
describing the point-cloud data.
Use [`Base.show`](https://docs.julialang.org/en/v1/base/io-network/#Base.show-Tuple%7BIO,%20Any%7D) to get a summary of the data, use indexing to access point records, use property access (e.g. `las.project_id`) to read global attributes, and use [`update`](@ref update(::LAS, ::NamedTuple)) to change global and per-point attributes.

# Point data records

The [`PointRecord`](@ref)s of a `LAS` can be accessed through indexing. Note
that when loading `LAS` data from a file (e.g. with [`LAS(filename)`](@ref
PointClouds.IO.LAS(::IO))), the point records are not loaded into memory by
default. Instead, the data is loaded in a lazy manner once it is accessed,
which allows working with files that do not fit into memory. The `points` field
of `LAS` gives access to the internal representation of the point records but
direct use is discouraged.

Point records are usually stored in one of 11 standardized point data record
formats (PDRFs) ranging from `PointRecord{0}` to `PointRecord{10}`. While all
PDRFs have many attributes (such as 3D coordinates and return intensity) in
common, the PDRFs differ in the exact set of attributes they support and the
precision at which the data is stored. As of LAS version 1.4, the PDRFs 0–5 are
considered legacy formats and the newer PDRFs 6–10 are preferred.

Refer to the [`PointRecord`](@ref) help text for the list of functions that can
be called on them to access their attributes. These accessor functions can also
be called directly on the `LAS` with one or multiple indices to access point
attributes.

# Variable length records (VLRs)

The variable length records of a LAS file store information about the
coordinate reference system (CRS), which can be accessed with the
[`getcrs`](@ref) function. The raw VLR data can be accessed through the `vlr`
field of `LAS`.

# Global point cloud attributes

  - `coord_scale::NTuple{3,Float64}`
  - `coord_offset::NTuple{3,Float64}`
  - `coord_min::NTuple{3,Float64}`
  - `coord_max::NTuple{3,Float64}`
  - `return_counts::Vector{UInt64}`
  - `version::Tuple{UInt8,UInt8}`: The version of the LAS file format (1.0 to 1.4) in the form of a `(major, minor)` tuple.
  - `source_id::UInt16`
  - `project_id::GUID`
  - `system_id::String`
  - `software_id::String`
  - `creation_date::Tuple{UInt16,UInt16}`
  - `has_adjusted_standard_gps_time::Bool`
  - `has_internal_waveform::Bool`
  - `has_external_waveform::Bool`
  - `has_synthetic_return_numbers::Bool`
  - `has_well_known_text::Bool`
"""
mutable struct LAS{P,V} <: AbstractPointCloud where {P<:AbstractVector{<:PointRecord}}

  # point & VLR data can be in custom containers
  points::P
  vlrs::V
  extra_data::Vector{UInt8}

  # rescaling of coordinate numbers
  coord_scale::NTuple{3,Float64}
  coord_offset::NTuple{3,Float64}

  # summary statistics of point data
  coord_min::NTuple{3,Float64}
  coord_max::NTuple{3,Float64}
  return_counts::Vector{UInt64}

  # file metadata
  version::NTuple{2,UInt8}
  source_id::UInt16
  project_id::GUID
  system_id::String
  software_id::String
  creation_date::NTuple{2,UInt16}

  # encoding flags
  has_adjusted_standard_gps_time::Bool
  has_internal_waveform::Bool
  has_external_waveform::Bool
  has_synthetic_return_numbers::Bool
  has_well_known_text::Bool
end

# iteration interface: forward to points field
Base.length(las::LAS) = length(las.points)
Base.iterate(las::LAS, args...) = iterate(las.points, args...)
Base.eltype(las::LAS) = eltype(las.points)
Base.isdone(las::LAS, args...) = isdone(las.points, args...)

# read-only indexing interface: forward to points field
Base.size(las::LAS) = size(las.points)
Base.firstindex(las::LAS) = firstindex(las.points)
Base.lastindex(las::LAS) = lastindex(las.points)
Base.getindex(las::LAS, ind::Integer) = getindex(las.points, ind)
function Base.getindex(las::LAS, inds)
  update(
    las;
    points = getindex(las.points, inds),
    coord_min = true,
    coord_max = true,
    return_counts = true,
  )
end
function Base.filter(f::Function, las::LAS)
  update(
    las;
    points = filter(f, las.points),
    coord_min = true,
    coord_max = true,
    return_counts = true,
  )
end
function Base.filter!(f::Function, las::LAS)
  filter!(f, las.points)
  update!(las; coord_min = true, coord_max = true, return_counts = true)
end

# equality testing
function Base.:(==)(las1::LAS, las2::LAS)
  # first test header fields
  for f in fieldnames(LAS)
    # points and vlrs are tested separately
    f == :points && continue
    f == :vlrs && continue
    getfield(las1, f) == getfield(las2, f) || return false
  end

  # check VLRs
  las1.vlrs == las2.vlrs || return false

  pts1, pts2 = las1.points, las2.points
  length(pts1) == length(pts2) || return false
  for (p1, p2) in zip(pts1, pts2)
    p1 == p2 || return false
  end

  true # LAS are the same
end

# extrema are based precomputed statistics
Base.minimum(las::LAS) = las.coord_min
Base.maximum(las::LAS) = las.coord_max
Base.extrema(las::LAS) = (minimum(las), maximum(las))

struct UnavailablePoints{T<:PointRecord} <: AbstractVector{T}
  length::Int
end

# iteration/indexing interface methods for LAS without point data
Base.size(pts::UnavailablePoints) = (pts.length,)
Base.iterate(pts::UnavailablePoints, args...) = error("Point data is unavailable")
Base.isdone(pts::UnavailablePoints, args...) = error("Point data is unavailable")
Base.getindex(pts::UnavailablePoints, args...) = error("Point data is unavailable")

# memory-mapped LAS point data (uncompressed)
struct MappedPoints{T<:PointRecord} <: AbstractVector{T}
  data::Vector{UInt8}
  function MappedPoints(::Type{T}, data::Vector{UInt8}) where {T<:PointRecord}
    @assert isconcretetype(T)
    rem(length(data), point_record_bytes(T)) == 0 ||
      @error "Point data has unexpected length (data may be truncated)"
    new{T}(data)
  end
end

# construct MappedPoints from IOStream
function MappedPoints(io::Base.IO, ::Type{P}, count) where {P}
  @assert isconcretetype(P)
  nb = point_record_bytes(P)
  available, rem = divrem(filesize(io) - position(io), nb)
  if available < count
    n = count - available
    eb = iszero(rem) ? "" : ", $rem trailing byte" * 's'^(rem > 1)
    @error "Point data ends prematurely ($n record$('s'^(n>1)) missing$eb)"
    count = available
  end
  # we cannot mmap as a Vector{pdrf_type} because such a vector can have different byte alignment
  data = Mmap.mmap(io, Vector{UInt8}, nb * count; grow = false)
  skip(io, nb * count) # advance IO past the mapped data
  MappedPoints(P, data)
end

# only read required attributes from mapped data instead of loading the whole point
function getattrs(attrs::Tuple, pts::MappedPoints{P}, ind::Integer) where {P}
  @boundscheck checkbounds(pts, ind)
  offset = (ind - 1) * point_record_bytes(P)
  map(attr -> (@inbounds readattr(P, attr, pts.data, offset)), attrs)
end

# when reading multiple points, only compute the offsets once
function getattrs(attrs::Tuple, pts::MappedPoints{P}, inds::AbstractRange) where {P}
  @boundscheck checkbounds(pts, inds)
  offsets = (inds .- 1) .* point_record_bytes(P)
  (
    map(attr -> (@inbounds readattr(P, attr, pts.data, offset)), attrs) for
    offset in offsets
  )
end

# iteration/indexing interface methods for memory-mapped point data
Base.size(pts::MappedPoints) = (div(length(pts.data), point_record_bytes(eltype(pts))),)
function Base.iterate(pts::MappedPoints, ind = 1)
  Base.isdone(pts, ind) ? nothing : (pts[ind], ind + 1)
end
Base.isdone(pts::MappedPoints, ind = 1) = ind > length(pts)
Base.getindex(pts::MappedPoints, inds::BitVector) = MaskedPoints(pts, inds)
Base.getindex(pts::MappedPoints, inds::OrdinalRange) = IndexedPoints(pts, inds)
function Base.getindex(pts::MappedPoints{P}, ind::Integer) where {P}
  P(getattrs(Val.(fieldnames(P)), pts, ind)...)
end
Base.filter(f::Function, pts::MappedPoints) = filter!(f, MaskedPoints(pts))

# subset of points, with lazy evaluation
struct MaskedPoints{T<:PointRecord,P<:AbstractVector{T}} <: AbstractVector{T}
  points::P
  mask::BitVector
  length::Base.RefValue{Int}

  function MaskedPoints(pts::P, inds::BitVector, count = sum(inds)) where {P}
    length(pts) == length(inds) || throw(BoundsError(pts, inds))
    new{eltype(pts),P}(pts, inds, Ref(count))
  end
end
struct IndexedPoints{I,T<:PointRecord,P<:AbstractVector{T}} <: AbstractVector{T}
  points::P
  indices::I

  function IndexedPoints(pts::P, inds::OrdinalRange) where {P}
    all(1 <= ind <= length(pts) for ind in extrema(inds)) || throw(BoundsError(pts, inds))
    new{typeof(inds),eltype(pts),P}(pts, inds)
  end
end

MaskedPoints(pts) = MaskedPoints(pts, trues(length(pts)), length(pts))
function MaskedPoints(pts::IndexedPoints)
  inds = falses(length(pts.points))
  inds[pts.indices] .= true
  MaskedPoints(pts.points, inds, length(pts))
end
Base.copy(pts::MaskedPoints) = MaskedPoints(pts.points, copy(pts.mask), length(pts))

# points filtered with logical indices and “precomputed” length
Base.size(pts::MaskedPoints) = (pts.length[],)
function Base.iterate(pts::MaskedPoints, state = 1)
  next = findnext(pts.mask, state)
  isnothing(next) ? nothing : (pts.points[next], next + 1)
end
function Base.getindex(pts::MaskedPoints, ind::Number)
  count = length(pts)
  1 <= ind <= count || throw(BoundsError(pts, ind))
  if ind - 1 <= count - ind # decide whether to search from front or back
    for ptind in 1:length(pts.points)
      pts.mask[ptind] || continue
      ind -= 1
      ind < 1 && return pts.points[ptind]
    end
  else
    for ptind in length(pts.points):-1:1
      pts.mask[ptind] || continue
      ind += 1
      ind > count && return pts.points[ptind]
    end
  end
  error("Could not get index for unknown reasons (this is a bug)")
end
function Base.getindex(pts::MaskedPoints, inds::OrdinalRange)
  all(1 <= ind <= length(pts) for ind in extrema(inds)) || throw(BoundsError(pts, inds))
  newmask = copy(pts.mask)
  iglobal = 0
  for ilocal in 1:length(pts)
    iglobal = findnext(newmask, iglobal + 1)
    newmask[iglobal] = ilocal in inds
  end
  MaskedPoints(pts, newinds, length(inds))
end
function Base.getindex(pts::MaskedPoints, inds::BitVector)
  length(pts) == length(inds) || throw(BoundsError(pts, inds))
  newmask = falses(length(pts.points))
  newmask[pts.mask] .= inds
  MaskedPoints(pts.points, newmask, sum(inds))
end
Base.filter(f, pts::MaskedPoints) = filter!(f, copy(pts))
function Base.filter!(f::F, pts::MaskedPoints) where {F<:Function}
  pts.length[] = 0
  for ind in 1:length(pts.mask)
    pts.mask[ind] || continue
    if f(pts.points[ind])
      pts.length[] += 1
    else
      pts.mask[ind] = false
    end
  end
  pts
end

# points filtered with range
Base.size(pts::IndexedPoints) = size(pts.indices)
function Base.iterate(pts::IndexedPoints, args...)
  it = iterate(pts.indices, args...)
  isnothing(it) ? nothing : (pts.points[it[1]], it[2])
end
Base.getindex(pts::IndexedPoints, ind::Number) = getindex(pts.points, pts.indices[ind])
function Base.getindex(pts::IndexedPoints, inds::OrdinalRange)
  IndexedPoints(pts.points, pts.indices[inds])
end
function Base.getindex(pts::IndexedPoints, inds::BitVector)
  length(inds) == length(pts) || throw(BoundsError(pts, inds))
  newinds = falses(length(pts.points))
  newinds[pts.indices] .= inds
  IndexedPoints(pts.points, newinds, sum(inds))
end
Base.filter(f, pts::IndexedPoints) = filter!(f, MaskedPoints(pts))

struct UpdatedPoints{N,A,T<:PointRecord,P<:AbstractVector{T}} <: AbstractVector{T}
  points::P
  attributes::NamedTuple{N,A}

  function UpdatedPoints(pts::P, attrs::NamedTuple) where {P}
    attrs = normalized_attributes(pts, attrs)
    for (k, a) in pairs(attrs)
      @assert a isa AbstractVector && axes(a) == axes(pts)
      # TODO: check names of attributes are valid
      # TODO: check types of attributes are correct
      k in fieldnames(eltype(pts)) || error("Invalid field name: $k")
    end
    new{keys(attrs),typeof(values(attrs)),eltype(pts),P}(pts, attrs)
  end
end

# iteration/indexing interface methods for LAS without point data
Base.size(pts::UpdatedPoints) = (length(pts.points),)
function Base.iterate(pts::UpdatedPoints, args...)
  # iterator state is (inner_state, next_index)
  next = iterate(pts.points, first.(args)...)
  isnothing(next) && return
  ind = isempty(args) ? 1 : last(only(args))
  pt, inner_state = next
  update(pt, map(a -> a[ind], pts.attributes)), (inner_state, ind + 1)
end
Base.isdone(pts::UpdatedPoints, args...) = isdone(pts.points, first.(args)...)
function Base.getindex(pts::UpdatedPoints, ind::Number)
  update(pts.points[ind], map(a -> a[ind], pts.attributes))
end
function Base.getindex(pts::UpdatedPoints, inds)
  UpdatedPoints(pts.points[inds], map(a -> a[inds], pts.attributes))
end

fileformat(::Type{<:LAS{T}}) where {T} = fileformat(T)
fileformat(::Type{<:MaskedPoints{T,P}}) where {T,P} = fileformat(P)
fileformat(::Type{<:IndexedPoints{I,T,P}}) where {I,T,P} = fileformat(P)
fileformat(::Type{<:UpdatedPoints{N,A,T,P}}) where {N,A,T,P} = fileformat(P)
fileformat(::Type{T}) where {T<:AbstractVector{<:PointRecord}} = "LAS"
fileformat(::Type{<:LASzipReader}) = "LAZ"
function pointformat(::Type{<:AbstractVector{<:PointRecord{F,N}}}) where {F,N}
  string("PointRecord{", F, iszero(N) ? "" : ",$N", "}")
end
function Base.summary(io::Base.IO, ::Type{T}) where {P,T<:LAS{P}}
  print(io, fileformat(T))
  get(io, :compact, false) || print(io, "{", pointformat(P), "}")
  nothing
end

function Base.summary(io::Base.IO, las::LAS)
  print(io, format(length(las)), "-point ")
  summary(io, typeof(las))
end

function format(n::Integer, delimiter = ',')
  s = string(n)
  l = length(s)
  parts = [s[max(i - 2, 1):i] for i in mod1(l, 3):3:l]
  join(parts, delimiter)
end

function Base.show(io::Base.IO, las::LAS)
  summary(IOContext(io, :compact => true), las)
  print(io, " (v$(las.version[1]).$(las.version[2])")
  print(io, ", ", point_record_description(eltype(las)), ", ")
  let (day, year) = las.creation_date
    if 1 <= day <= 366
      date = Dates.Date(year) + Dates.Day(day - 1)
      print(io, Dates.format(date, "dd u yyyy"))
    else
      print(io, "Day ", day, " Year ", year)
    end
  end
  print(io, ")")

  pad = 16
  print(io, rpad("\n  Source ID", pad), "=> ")
  print(io, iszero(las.source_id) ? "(empty)" : string(las.source_id))
  print(io, rpad("\n  Project ID", pad), "=> ")
  print(io, las.project_id)
  print(io, rpad("\n  System ID", pad), "=> \"", las.system_id, "\"")
  print(io, rpad("\n  Software ID", pad), "=> \"", las.software_id, "\"")
  print(io, rpad("\n  X-Coordinates", pad), "=> ")
  print(io, las.coord_min[1], " … ", las.coord_max[1])
  print(io, rpad("\n  Y-Coordinates", pad), "=> ")
  print(io, las.coord_min[2], " … ", las.coord_max[2])
  print(io, rpad("\n  Z-Coordinates", pad), "=> ")
  print(io, las.coord_min[3], " … ", las.coord_max[3])

  ret = map(enumerate(las.return_counts)) do (ind, count)
    iszero(count) ? missing : string(ind, " => ", format(count))
  end
  print(io, rpad("\n  Return-Counts", pad), "=> ", "[", join(skipmissing(ret), ", "), "]")

  nextra = length(las.extra_data)
  if !iszero(nextra)
    limit = nextra > 8 ? 6 : nextra
    print(io, rpad("\n  Extra Data", pad), "=> ")
    print(io, "[", join((sprint(show, b) for b in las.extra_data[1:limit]), ", "))
    nextra > limit && print(io, " … (", nextra - limit, " more bytes)")
    print(io, "]")
  end

  nvlr = length(las.vlrs)
  print(io, "\n  Variable-Length Records")
  nprint = nvlr > 7 ? 5 : nvlr
  map(las.vlrs[1:nprint]) do vlr
    print(io, "\n    => ")
    show(io, vlr)
  end
  nvlr > nprint && print(io, "\n    => ($(nvlr - nprint) more records)")
end

function read_las_signature(io)
  sig = ntuple(_ -> read(io, UInt8), 4)
  if sig != (UInt8('L'), UInt8('A'), UInt8('S'), UInt8('F'))
    error("Invalid file signature: $sig")
  end
end

write_las_signature(io) = write(io, UInt8('L'), UInt8('A'), UInt8('S'), UInt8('F'))

"""
    read(io::IO, LAS; kws...)
    read(filename::AbstractString, LAS; kws...)
    read(url::AbstractString, LAS; kws...)

Read LAS/LAZ data from a file, URL, or an arbitrary `IO` input (not supported
for compressed LAZ data). URLs can be passed as a string starting with `"http"`
or as a `URI` from the `URIs`/`HTTP` package.

# Keywords

  - `read_points`: If set to `:lazy` (default), points are only read to memory
    when accessed, allowing processing of point clouds that do not fit into
    memory. If set to `true`, all points are read into memory right away. If set
    to `false`, points are not read at all and only header information is
    available.
  - `cache`: Whether the downloaded data should be saved as a temporary file (if
    set to `true`), saved to a specific path (if set to a string), or not saved
    at all (if set to `false`, not supported for compressed LAZ data). Defaults
    to `true` and only applies when the input is a URL.
  - `insecure`: Whether to allow downloading data from `url` without SSL
    verification (default: `false`).
"""
Base.read(io::Base.IO, ::Type{LAS}; kws...) = LAS(io; kws...)
function Base.read(filename::Union{AbstractString,HTTP.URI}, ::Type{LAS}; kws...)
  LAS(filename; kws...)
end

unwrap(io::IOContext) = unwrap(io.io)
unwrap(io::Base.IO) = io

function LAS(uri::HTTP.URI; cache = true, insecure = false, kws...)
  isfile(cache) && return LAS(cache; kws...)

  # configuration options for HTTP requests
  cfg = (; require_ssl_verification = !insecure)

  # if points are not required, try to download only the header data
  if get(kws, :read_points, true) == false
    # check if HTTP range requests are supported
    if HTTP.header(HTTP.head(uri; cfg...), "Accept-Ranges", "none") == "bytes"
      point_offset =
        only(reinterpret(UInt32, HTTP.get(uri, ("Range" => "bytes=96-99",); cfg...).body))
      las_head = HTTP.get(uri, ("Range" => "bytes=0-$point_offset",); cfg...).body
      return LAS(IOBuffer(las_head); kws...)
    else
      @warn "Server does not support range requests, downloading whole file"
    end
  end

  # downloading to cache
  if cache == false
    @info "Downloading LAS data to memory"
    return LAS(IOBuffer(HTTP.get(uri; cfg...).body); kws...)
  end

  cache = cache == true ? tempname() : cache
  @info "Downloading LAS data to `$cache`"
  HTTP.download(string(uri), cache; cfg...)
  LAS(cache; kws...)
end

function LAS(input::AbstractString; kws...)
  # pass file name in context in case we need access to the original file
  @debug "reading LAS from $input"
  isfile(input) &&
    return open(io -> LAS(IOContext(io, :filename => input); kws...), input, "r")

  # download data if URL was supplied
  startswith(input, "http") && return LAS(HTTP.URI(input); kws...)

  # fallback
  error("Could not load LAS data from `$input`")
end

"""
    LAS(io)
    LAS(filename)
    LAS(url; cache = true)

Read LAS/LAZ data from a file, URL, or an arbitrary `IO` input (not supported for compressed LAZ data). See [`Base.read(input, LAS)`](@ref Base.read(::IO, ::Type{LAS})) for details.
"""
function LAS(io::Base.IO; read_points = :auto, override_crs = nothing)
  read_las_signature(io)

  source_id = read(io, UInt16)

  # parse global encoding bit field
  encoding = read(io, UInt16)
  if !iszero(encoding >> 5)
    bits = string(encoding >> 5; base = 2, pad = 11)
    @warn "Reserved bits 5–16 set in global encoding: $(bits)xxxxx"
  end
  has_adjusted_standard_gps_time = isodd(encoding)
  has_internal_waveform = isodd(encoding >> 1)
  has_external_waveform = isodd(encoding >> 2)
  has_synthetic_return_numbers = isodd(encoding >> 3)
  has_well_known_text = isodd(encoding >> 4)

  project_id = read(io, GUID)

  # parse version and check whether it is supported (but always continue)
  version = ntuple(_ -> read(io, UInt8), 2)
  if version[1] == 1
    version[2] <= 4 || @error "Unsupported minor LAS version v$(version[1]).$(version[2])"
  else
    @error "Unsupported major LAS version v$(version[1]).$(version[2])"
  end

  # parse remaining descriptive fields
  system_id = bytes_to_string(read!(io, Vector{UInt8}(undef, 32)))
  software_id = bytes_to_string(read!(io, Vector{UInt8}(undef, 32)))
  creation_date = ntuple(_ -> read(io, UInt16), 2)

  # parse various data-length fields
  header_size = read(io, UInt16)
  point_data_offset = read(io, UInt32)
  vlr_count = read(io, UInt32)
  pdrf_number = read(io, UInt8)
  pdrf_bytes = read(io, UInt16)
  point_count_total = UInt64(read(io, UInt32))
  return_counts = zeros(UInt64, 15)
  foreach(i -> return_counts[i] = read(io, UInt32), 1:5)

  # parse coordinates and their offset
  coord_scale = ntuple(_ -> read(io, Float64), 3)
  coord_offset = ntuple(_ -> read(io, Float64), 3)
  coord_min, coord_max = let
    xmax, xmin = ntuple(_ -> read(io, Float64), 2)
    ymax, ymin = ntuple(_ -> read(io, Float64), 2)
    zmax, zmin = ntuple(_ -> read(io, Float64), 2)
    (xmin, ymin, zmin), (xmax, ymax, zmax)
  end

  # to support streams such as `stdin` which do not support `position(io)`
  # and `seek(io)`, we manually keep track of the bytes that have been read
  bytes_read = 227

  if version < (1, 2)
    if has_adjusted_standard_gps_time
      @warn "Adjusted Standard GPS time is not officially supported before LAS v1.2"
    end
  end

  if version < (1, 3)
    if has_internal_waveform || has_external_waveform
      @warn "Waveform data packets are not officially supported before LAS v1.3"
    end
    if has_synthetic_return_numbers
      @warn "Marking return numbers as synthetic is not officially supported before LAS v1.3"
    end
  else
    if has_internal_waveform && has_external_waveform
      @warn "Waveform data packets marked as both internal and external"
    end
    if has_internal_waveform || has_external_waveform
      # TODO: add support for waveform data
      @warn "Loading waveform data packets is currently not implemented"
    end

    # parse start of waveform data packet record
    _ = read(io, UInt64)

    # add bytes from LAS v1.4 fields
    bytes_read += 8
  end

  if version < (1, 4)
    if has_well_known_text
      @warn "Well Known Text is not officially supported before LAS v1.4"
    end
  else
    if has_internal_waveform
      @warn "Internal waveform data packets are deprecated in LAS v1.4"
    end

    # parse extended variable length records
    # TODO: add support for loading EVLRs
    evlr_start = read(io, UInt64)
    n_evlr = read(io, UInt32)
    iszero(n_evlr) || @warn "Loading EVLRs is currently not implemented"

    # parse new 64-bit record counts with support for up to 15 returns;
    # if legacy values are provided they should match the 64-bit values
    # but take precedence if they do not match
    total_64 = read(io, UInt64)
    return_counts_64 = read!(io, Vector{UInt64}(undef, 15))
    if iszero(point_count_total)
      point_count_total = total_64
    elseif point_count_total != total_64
      @warn "Point count $total_64 does not match legacy value $point_count_total"
    end
    for (i, n) in enumerate(return_counts_64)
      n_legacy = return_counts[i]
      if iszero(n_legacy)
        return_counts[i] = n
      elseif n_legacy != n
        @warn "Point count $n for return $i does not match legacy value $n_legacy"
      end
    end

    # add bytes from LAS v1.4 fields
    bytes_read += 140
  end

  # but we allow skipping extra bytes that may be introduced in future LAS
  # versions (user-defined bytes are not allowed here by the LAS v1.4 spec,
  # only after the VLRs)
  if bytes_read < header_size
    count = header_size - bytes_read
    @warn "Skipping $count unexpected bytes in public header block"
    skip(io, count)
    bytes_read += count
  elseif bytes_read > header_size
    @error "Header size smaller than expected"
    # continue in case the header size was set incorrectly but the position
    # is still correct
  end
  bytes_read > point_data_offset && error("Header is larger than point-data offset")

  # read VLR data only up to the point-data offset so we can still attempt to
  # read the point data if there is an issue with the VLR data
  remaining = point_data_offset - bytes_read
  vlrs = VariableLengthRecord[]
  for ind in 1:vlr_count
    if iszero(remaining)
      n = vlr_count - ind + 1
      s = n > 1 ? "s" : ""
      @error "VLR data ends prematurely ($n record$s missing)"
      break
    end
    vlr = read(io, VariableLengthRecord; version = version, max_bytes = remaining)
    isnothing(vlr) && break
    push!(vlrs, vlr)
    remaining -= 54 + length(vlr.data)
  end
  extra_data = read(io, remaining)

  # check if it is a compressed LAZ file
  # VLR mentioned in https://www.iana.org/assignments/media-types/application/vnd.laszip
  islaz = !isnothing(get_vlr(vlrs, "laszip encoded", 22204))
  if islaz
    pdrf_number >= 128 || error("LAZ file has invalid point data record format")
    pdrf_number -= 0x80
    # lasZIP VLR is no longer meaningful once the data is loaded
    # and can cause issues if written to a regular LAS file
    delete_vlr!(vlrs, "laszip encoded", 22204)
  end

  # read point data, without choking on truncated files
  pdrf_type = point_record_type(pdrf_number, pdrf_bytes)
  points = if read_points == false
    # do not read points, just save point type & count
    UnavailablePoints{pdrf_type}(point_count_total)
  elseif read_points == :laszip || (islaz && read_points in (:auto, true))
    filename = extract_filename(io)
    isnothing(filename) && error("Could not determine filename for LASzip")
    r = LASzipReader(filename, pdrf_type, point_count_total)
    read_points == true ? collect(r) : r
  elseif read_points == :stream
    # TODO: automatically determine when points need to be read from stream
    # TODO: consider using BufferedStreams for better performance
    points = Vector{pdrf_type}(undef, point_count_total)
    io = unwrap(io) # remove context
    pos = position(io) # to compute number of elements, if incomplete
    try
      read_points!(io, points)
    catch ex
      ex isa EOFError || rethrow()
      resize!(points, div(position(io) - pos, pdrf_bytes))
      n = point_count_total - length(points)
      # TODO: check if discarded data can be added to error message
      @error "Point data ends prematurely ($n record$('s'^(n>1)) missing)"
    end
    eof(io) || @error "Input longer than expected"
    points
  elseif read_points in (:auto, true)
    pts = MappedPoints(unwrap(io), pdrf_type, point_count_total)
    # TODO: allow for EVLR data after point data
    eof(io) || @error "Input longer than expected"
    read_points == true ? collect(pts) : pts
  else
    error("Invalid keyword argument `read_points = $read_points`")
  end

  LAS{typeof(points),typeof(vlrs)}(
    points,
    vlrs,
    extra_data,
    # rescaling of coordinate numbers
    coord_scale,
    coord_offset,
    # summary statistics of point data
    coord_min,
    coord_max,
    return_counts,
    # file metadata
    version,
    source_id,
    project_id,
    system_id,
    software_id,
    creation_date,
    # encoding flags
    has_adjusted_standard_gps_time,
    has_internal_waveform,
    has_external_waveform,
    has_synthetic_return_numbers,
    has_well_known_text,
  )
end

read_points!(io, pts) =
  foreach(eachindex(pts)) do ind
    @inbounds pts[ind] = read(io, eltype(pts))
  end

function Base.write(filename::AbstractString, las::LAS; format = nothing)
  if isnothing(format)
    format = if '.' in filename
      filename[findlast('.', filename)+1:end]
    else
      fileformat(typeof(las))
    end
  end
  lowercase(format) in ("las", "laz") || error("Unsupported format: `$format`")
  open(io -> Base.write(io, las; format = format), filename, "w")
end

"""
    write(io::IO, las::LAS; kws...)
    write(filename::AbstractString, las::LAS; kws...)

Write point-cloud data to a new LAS file or an arbitrary `IO` output.

# Keywords

  - `format`: Can be set to `"las"` for regular uncompressed LAS data, or to
    `"laz"` to compress the output with
    [LASzip](https://github.com/LASzip/LASzip). By default, the format is derived
    from the file extension or set to `"las"` otherwise.
"""
function Base.write(io::Base.IO, las::LAS; format = "las")
  format = lowercase(format)
  format == "las" || error("Writing to LAZ is not yet implemented")
  major_version, minor_version = las.version
  major_version == 1 ||
    error("Unsupported major LAS version v$major_version.$minor_version")
  minor_version <= 4 ||
    error("Unsupported minor LAS version v$major_version.$minor_version")

  write_las_signature(io)
  write(io, las.source_id)
  encoding =
    UInt16(las.has_adjusted_standard_gps_time) |
    UInt16(las.has_internal_waveform) << 1 |
    UInt16(las.has_external_waveform) << 2 |
    UInt16(las.has_synthetic_return_numbers) << 3 |
    UInt16(las.has_well_known_text) << 4
  write(io, encoding)
  write(io, las.project_id)
  write(io, las.version...)
  write(io, string_to_bytes(las.system_id, 32))
  write(io, string_to_bytes(las.software_id, 32))
  write(io, las.creation_date...)
  header_size = (227, 227, 227, 235, 375)[minor_version+1]
  write(io, UInt16(header_size))
  vlr_size = sum(54 + length(vlr.data) for vlr in las.vlrs; init = 0)
  write(io, UInt32(header_size + vlr_size + length(las.extra_data)))
  write(io, UInt32(length(las.vlrs)))

  pdrf_number = point_record_number(eltype(las))
  write(io, UInt8(pdrf_number))
  write(io, UInt16(sum(sizeof(t) for t in fieldtypes(eltype(las.points)))))
  if (minor_version <= 1 && pdrf_number > 1) ||
     (minor_version <= 2 && pdrf_number > 3) ||
     (minor_version <= 3 && pdrf_number > 5)
    error("Point Data Record Format $pdrf_number is not allowed in LAS v1.$(minor_version)")
  end

  # recomputing & checking summary values from point data
  coord_min, coord_max, return_counts = recompute_summary(las)
  coord_min = ntuple(3) do ind
    computed, original = coord_min[ind], las.coord_min[ind]
    if computed < original && !isapprox(computed, original)
      @warn "Updating minimum $("xyz"[ind])-coordinate from $(original) to $computed"
      return computed
    end
    original
  end
  coord_max = ntuple(3) do ind
    computed, original = coord_max[ind], las.coord_max[ind]
    if computed > original && !isapprox(computed, original)
      @warn "Updating maximum $("xyz"[ind])-coordinate from $original to $computed"
      return computed
    end
    original
  end
  return_counts = ntuple(15) do ind
    computed, original = return_counts[ind], las.return_counts[ind]
    if computed != original
      @warn "Updating point count for return number $ind from $original to $computed"
    end
    return computed
  end

  # legacy point count (total & by return)
  if minor_version < 4 && length(las) > typemax(UInt32)
    error("LAS v1.$(minor_version) does not support more than $(typemax(UInt32)) points")
  end
  if any(n > length(las) for n in return_counts)
    error("Points count by return type exceeds total point count")
  end
  if length(las) <= typemax(UInt32) && pdrf_number <= 5
    write(io, UInt32(length(las)))
    foreach(i -> write(io, UInt32(return_counts[i])), 1:5)
  else
    foreach(_ -> write(io, zero(UInt32)), 1:6)
  end

  # coordinate-related fields
  write(io, las.coord_scale...)
  write(io, las.coord_offset...)
  write(io, coord_max[1])
  write(io, coord_min[1])
  write(io, coord_max[2])
  write(io, coord_min[2])
  write(io, coord_max[3])
  write(io, coord_min[3])

  # fields introduced in LAS v1.3
  if minor_version >= 3
    # TODO: implement support for waveform data
    # start of waveform data packet record
    write(io, zero(UInt64))
  end

  # fields introduced in LAS v1.4
  if minor_version >= 4
    # TODO: implement support for extended variable length records
    # start of first extended variable length record
    write(io, zero(UInt64))
    # number of extended variable length records
    write(io, zero(UInt32))

    # point count (total & by return)
    write(io, UInt64(length(las)))
    foreach(i -> write(io, return_counts[i]), 1:15)
  else
    for ind in 6:15
      if !iszero(return_counts[ind])
        @warn "Some points have a return number of $ind (should be between 1 and 5)"
      end
    end
  end

  # write extra data, VLRs & points
  foreach(vlr -> write(io, vlr; minor_version = minor_version), las.vlrs)
  write(io, las.extra_data)
  foreach(pt -> write(io, pt), las.points)
end

LAS(; kws...) = LAS(PointRecord{6}; kws...)
LAS(::Type{T}; kws...) where {T<:PointRecord} = LAS(point_record_type(T)[]; kws...)

"""
    LAS([T,] points; kws...)

Create a new `LAS` with points of type `T <: PointRecord`. The `points` can be
passed as an `AbstractVector` of `PointRecord`s or as a `NamedTuple`, where the
keys correspond to the point attribute names and the values are `AbstractVector`s. The keyword arguments set the corresponding fields of the `LAS` type.
"""
function LAS(
  ::Type{T},
  points::NamedTuple;
  coord_scale = nothing,
  coord_offset = nothing,
  kws...,
) where {T<:PointRecord}
  coords = (points.x, points.y, points.z)
  scalings = pick_scalings(coords; scale = coord_scale, offset = coord_offset)
  points = las_points(T, points; scalings...)
  LAS(points; scalings..., kws...)
end

function LAS(points::NamedTuple; kws...)
  extra_bytes = haskey(points, :extra_bytes) ? length(first(points.extra_bytes)) : 0
  LAS(PointRecord{6,extra_bytes}, points; kws...)
end

function LAS(
  points::Vector{<:PointRecord};
  # rescaling of coordinate numbers
  coord_scale::NTuple{3,Float64} = (1.0, 1.0, 1.0),
  coord_offset::NTuple{3,Float64} = (0.0, 0.0, 0.0),
  # file metadata
  version = v"1.4",
  source_id::Integer = 0,
  project_id::GUID = zero(GUID),
  system_id::String = "",
  software_id::String = "PointClouds.jl",
  creation_date::Dates.Date = Dates.today(),
  # encoding flags
  has_adjusted_standard_gps_time::Bool = false,
  has_internal_waveform::Bool = false,
  has_external_waveform::Bool = false,
  has_synthetic_return_numbers::Bool = false,
  has_well_known_text::Bool = false,
)

  # validate/normalize input
  version = las_version(version)
  validate_las_string.((system_id, software_id); length = 32)
  creation_date = las_date(creation_date)

  # compute summary statistics
  coord_min, coord_max, return_counts = recompute_summary(coord_scale, coord_offset, points)

  LAS(
    points,
    VariableLengthRecord[],
    UInt8[],
    # rescaling of coordinate numbers
    coord_scale,
    coord_offset,
    # summary statistics of point data
    coord_min,
    coord_max,
    return_counts,
    # file metadata
    version,
    UInt16(source_id),
    project_id,
    system_id,
    software_id,
    creation_date,
    # encoding flags
    has_adjusted_standard_gps_time,
    has_internal_waveform,
    has_external_waveform,
    has_synthetic_return_numbers,
    has_well_known_text,
  )
end

function LAS(las::LAS; extent = nothing)
  # TODO: allow changing more parts of the data

  # unpack fields that may change
  points = las.points
  coord_min = las.coord_min
  coord_max = las.coord_max
  return_counts = las.return_counts

  if !isnothing(extent)
    nd = length(first(extent)) # extent can have less than 3 dimensions
    @assert length(extent) == 2 && length(last(extent)) == nd <= 3
    coord_min = ntuple(d -> get(extent[1], d, coord_min[d]), 3)
    coord_max = ntuple(d -> get(extent[2], d, coord_max[d]), 3)
    all(coord_min .<= coord_max) || error("Lower bounds of extent exceed upper bounds")
    int_min = cld.(coord_min[1:nd] .- las.coord_offset[1:nd], las.coord_scale[1:nd])
    int_max = fld.(coord_max[1:nd] .- las.coord_offset[1:nd], las.coord_scale[1:nd])

    points = Vector{eltype(las)}()
    return_counts = zeros(UInt64, 15)

    for pt in las
      all(int_min .<= coordinates(Integer, pt)[1:nd] .<= int_max) || continue
      push!(points, pt)
      r = return_number(pt)
      !iszero(r) && (return_counts[r] += 1)
    end
    @info "$(length(las.points)) points reduced to $(length(points)) points"
  end

  LAS{typeof(points),typeof(las.vlrs)}(
    points,
    las.vlrs,
    las.extra_data,
    # rescaling of coordinate numbers
    las.coord_scale,
    las.coord_offset,
    # summary statistics of point data
    coord_min,
    coord_max,
    return_counts,
    # file metadata
    las.version,
    las.source_id,
    las.project_id,
    las.system_id,
    las.software_id,
    las.creation_date,
    # encoding flags
    las.has_adjusted_standard_gps_time,
    las.has_internal_waveform,
    las.has_external_waveform,
    las.has_synthetic_return_numbers,
    las.has_well_known_text,
  )
end

function recompute_summary(las::LAS)
  recompute_summary(las.coord_scale, las.coord_offset, las.points)
end

function recompute_summary(coord_scale, coord_offset, points)
  return_counts = zeros(UInt64, 15)
  xmin, ymin, zmin = ntuple(_ -> typemax(Int32), 3)
  xmax, ymax, zmax = ntuple(_ -> typemin(Int32), 3)
  for pt in points
    r = return_number(pt)
    !iszero(r) && (return_counts[r] += 1)
    xmin, ymin, zmin = min.((xmin, ymin, zmin), coordinates(Integer, pt))
    xmax, ymax, zmax = max.((xmax, ymax, zmax), coordinates(Integer, pt))
  end
  coord_min = (xmin, ymin, zmin) .* coord_scale .+ coord_offset
  coord_max = (xmax, ymax, zmax) .* coord_scale .+ coord_offset
  coord_min, coord_max, return_counts
end

"""
    getcrs([T], las::LAS)

Obtain the coordinate reference system (CRS) of a [`LAS`](@ref), either in the
format contained in the `LAS` or converted to the type `T`. The LAS format
stores CRS data either in the binary format defined by the [GeoTIFF
standard](https://docs.ogc.org/is/19-008r4/19-008r4.html) or using the
well-known text (WKT) representation defined in the [OpenGIS® Coordinate
Transformation Service Standard](https://www.ogc.org/standards/ct/). The former
is represented by the custom `GeoKeys` type while the latter is represented by
a `String`. Currently, only the conversion from `GeoKeys` to a WKT `String` is
implemented, but this allows passing CRS information obtained with
`getcrs(String, las)` to other libraries such as
[Proj.jl](https://github.com/JuliaGeo/Proj.jl). Note however that the
conversion does a strict interpretation of the `GeoKeys` data and may not be
able to convert incomplete/non-standard CRS data.
"""
function getcrs(::Type{T}, las::LAS) where {T}
  crs = getcrs(las)
  crs isa T && return crs
  if crs isa GeoKeys && T <: AbstractString
    gk2wkt(crs)
  else
    error("Could not convert CRS to the requested format")
  end
end
getcrs(las::LAS) = getcrs(las.has_well_known_text ? String : GeoKeys, las.vlrs)

"""
    gettransform(las, target)

Create a `Proj` coordinate transfrom from the CRS of the LAS to the `target`
CRS. Internal use only.
"""
function gettransform(las::LAS, target)
  source = getcrs(String, las)
  target == source && return identity
  Proj.Transformation(source, target; always_xy = true)
end
gettransform(las::LAS, ::Nothing) = identity

"""
    coordinates(las::LAS, inds = :; crs)

Obtain the x-, y-, and z-coordinate of one or multiple point records as a tuple
of floating-point numbers. The coordinate reference system (CRS) of the `LAS`
is used unless a different `crs` is specified. To obtain coordinates of
multiple points, pass a range of indices or `:` (default) as the `index`
argument.

# Keywords

  - `crs`: Transform the coordinates to a new coordinate reference system `crs`
    instead of the current CRS of the `LAS`.

See also: [`LAS`](@ref), [`getcrs`](@ref)
"""
function coordinates(las::LAS, args...; crs = nothing)
  tf = gettransform(las, crs)
  attribute(Val(:coords), las, args...) do coords
    tf(coords .* las.coord_scale .+ las.coord_offset)
  end
end

"""
    coordinates(Function, las::LAS; crs)

Create a function that takes a `PointRecord` as its argument and returns the
rescaled coordinates of that point; in the coordinate reference system (CRS) of
`las` unless a different `crs` is specified.

See also: [`LAS`](@ref), [`getcrs`](@ref)
"""
function coordinates(::Type{Function}, las::LAS; crs = nothing)
  tf = gettransform(las, crs)
  pt -> tf(coordinates(Integer, pt) .* las.coord_scale .+ las.coord_offset)
end

# for all other attributes, no information from the LAS is needed, so they can
# simply be forwarded to the `attribute` function of the points vector
attribute(f, attr, las::LAS, ind::Integer) = attribute(f, attr, las.points, ind)
attribute(f, attr, las::LAS, args...) = attribute(f, attr, las.points, args...)

"""
    update(las::LAS, [attributes]; kws...)

Create a copy of a `LAS` that replaces point attributes with the `attributes`
provided as a `NamedTuple`. The keyword arguments update the corresponding global attributes of the [`LAS`](@ref).

See also: [`update!`](@ref)
"""
function update(las::LAS, attrs::NamedTuple = (;); kws...)

  # validate arguments
  map(keys(kws)) do f
    hasfield(LAS, f) || throw(ArgumentError("Cannot assign unknown field `$f`"))
  end
  map((:system_id, :software_id)) do f
    haskey(kws, f) && validate_las_string(kws[f]; length = 32)
  end

  # prepare new points
  points = haskey(kws, :points) ? kws[:points] : las.points
  if !isempty(attrs)
    points = UpdatedPoints(points, attrs)
  end

  # check if we need to update the summary statistics
  summary_kws = (:coord_min, :coord_max, :return_counts)
  # 1) if the summarized fields have changed
  update_summary = any(haskey(attrs, k) for k in (:x, :y, :z, :coordinates, :return_number))
  # 2) if the coordinate scaling has changed
  update_summary |= any(haskey(kws, k) for k in (:coord_scale, :coord_offset))
  # 3) and if it is explicitly requested, but never if it is explicitly provided
  update_summary = NamedTuple(map(summary_kws) do k
    k => haskey(kws, k) ? kws[k] == true : update_summary
  end)
  summary = if any(update_summary)
    scale = get(kws, :coord_scale, las.coord_scale)
    offset = get(kws, :coord_offset, las.coord_offset)
    NamedTuple{summary_kws}(recompute_summary(scale, offset, points))
  end

  # build new LAS with updated fields
  args = map(fieldnames(LAS)) do f
    f == :points && return points
    haskey(kws, f) || return getfield(las, f)
    f in summary_kws && update_summary[f] && return summary[f]
    kws[f]
  end
  LAS(args...)
end

"""
    update!(las::LAS, [attributes]; kws...)

Update a `LAS` by replacing point attributes with the `attributes` provided as
a `NamedTuple`. This is only supported if the point records of the `LAS` have
been loaded into memory.

The keyword arguments update the corresponding global attributes of the
[`LAS`](@ref), of which only `coord_min`, `coord_max`, and `return_counts` can
be modified in-place.

See also: [`update`](@ref)
"""
function update!(las::LAS, attributes::NamedTuple = (;); kws...)
  # TODO: in-place update where possible
  error("Not yet implemented")
end

"""
    PointRecord{F,N}

A point data record in the point data record format (PDRF) `F` (usually between
0 and 10) with `N` extra bytes (usually zero), as defined in the ASPRS “LAS”
format.

## Point record attributes

The attributes of point records can be accessed with the functions below;
directly accessing struct fields is discouraged. Note that some attributes are
not all available for all PDRFs.

  - 3D position: [`coordinates`](@ref)
  - color information: [`color_channels`](@ref) *(RGB for PDRFs 2/3/5/7, RGB + NIR for PDRFs 8/10)*
  - time at which point was recorded: [`gps_time`](@ref) *(PDRFs 1 & 3–10)*
  - information about the laser pulse return: [`intensity`](@ref), [`return_number`](@ref), [`return_count`](@ref), [`waveform_packet`](@ref) *(PDRFs 4/5/9/10 only)*
  - scanner/flight path information: [`scan_angle`](@ref) *(higher resolution for PDRFs 6–10)*, [`is_left_to_right`](@ref), [`is_right_to_left`](@ref), [`is_edge_of_line`](@ref), [`scanner_channel`](@ref) *(PDRFs 6–10 only)*, [`source_id`](@ref)
  - point record classification: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](@ref) *(all PDRFs, based on classification for PDRF 0–5)*, [`is_synthetic`](@ref), [`is_withheld`](@ref)
  - custom attributes: [`user_data`](@ref), [`extra_bytes`](@ref)
"""
abstract type PointRecord{F,N} end

const LegacyPointRecord{N} = Union{
  PointRecord{0,N},
  PointRecord{1,N},
  PointRecord{2,N},
  PointRecord{3,N},
  PointRecord{4,N},
  PointRecord{5,N},
}

const WaveformPacket = Tuple{UInt8,UInt64,UInt32,Float32,Float32,Float32,Float32}

struct UnknownPointRecord{F,N} <: PointRecord{F,N}
  data::NTuple{N,UInt8}
end

struct PointRecord0{N} <: PointRecord{0,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord1{N} <: PointRecord{1,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 1: gps time
  gps_time::Float64
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord2{N} <: PointRecord{2,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 2: rgb color
  color_channels::NTuple{3,UInt16}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord3{N} <: PointRecord{3,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 3: gps time & rgb color
  gps_time::Float64
  color_channels::NTuple{3,UInt16}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord4{N} <: PointRecord{4,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 4: gps time & waveform packets
  gps_time::Float64
  waveform_packet::WaveformPacket
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord5{N} <: PointRecord{5,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 5: gps time, rgb color & waveform packets
  gps_time::Float64
  color_channels::NTuple{3,UInt16}
  waveform_packet::WaveformPacket
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord6{N} <: PointRecord{6,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord7{N} <: PointRecord{7,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 7: rgb color
  color_channels::NTuple{3,UInt16}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord8{N} <: PointRecord{8,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 8: rgb + nir color
  color_channels::NTuple{4,UInt16}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord9{N} <: PointRecord{9,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 9: waveform packets
  waveform_packet::WaveformPacket
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord10{N} <: PointRecord{10,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  metadata::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 10: rgb + nir color & waveform packets
  color_channels::NTuple{4,UInt16}
  waveform_packet::WaveformPacket
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

"""
    readattr(::Type{<:PointRecord}, attr::Val, args...)

Read a point attribute from the data in `args`. This is an internal function
that is used by several point sources to provide access to individual
attributes of a single point.
"""
function readattr end

"""
    readattr(T, attr, pt::PointRecord)

Read an attribute `attr` from an existing point record `pt` of type `T`.
"""
readattr(::Type{P}, ::Val{F}, pt::P) where {P<:PointRecord,F} = getfield(pt, F)

"""
    readattr(T, attr, data::AbstractVector{UInt8}, offset = 0)

Read an attribute `attr` for a point record of type `T` from raw LAS `data`, at
an (optional) `offset`.
"""
function readattr(
  ::Type{P},
  ::Val{F},
  data::AbstractVector{UInt8},
  offset::Integer = 0,
) where {P<:PointRecord,F}
  T = fieldtype(P, F)
  T <: Tuple{} && return () # reinterpret does not work for empty tuples
  # careful when making changes: sum should be computed at compile time!
  offset +=
    sum(ntuple(ind -> sizeof(fieldtype(P, ind)), Base.fieldindex(P, F) - 1); init = 0)
  inds = (1:sizeof(T)) .+ offset
  @boundscheck checkbounds(data, inds)
  @inbounds reinterpret(T, view(data, inds))[]
end

# reading & writing to/from IO

"""
    readattr(T, attr, io::IO)

Read an attribute `attr` for a point record of type `T` from `io`.
"""
function readattr(::Type{P}, ::Val{F}, io::Base.IO) where {P<:PointRecord,F}
  T = fieldtype(P, F)
  T <: Tuple ? map(Ti -> Base.read(io, Ti), fieldtypes(T)) : Base.read(io, T)
end

function Base.read(io::Base.IO, ::Type{P}) where {P<:PointRecord}
  P(map(attr -> readattr(P, attr, io), Val.(fieldnames(P)))...)
end

function Base.write(io::Base.IO, pt::P) where {P<:PointRecord}
  fields = ntuple(ind -> getfield(pt, ind), fieldcount(P))
  foreach(val -> write.((io,), val), fields) # broadcast for tuples
end

"""
    getattrs(attrs::Tuple, args...)

Obtain the attributes given by `attrs` as a `Tuple` of `Val`s with their field
names from the point data given in `args`.

This internal function is meant to be extended for different point data sources
in order to provide efficient access to a subset of the attributes in a more
efficient way than the default implementation for `AbstractVector`s, which
relies on `getindex(args...)`.
"""
function getattrs end

"""
    getattrs(attrs::Tuple, p::PointRecord)
    getattrs(attrs::Tuple, points::AbstractVector{<:PointRecord}, ind::Integer)

Obtain a tuple of attributes of a single point record, either given directly as
`p` or read from `points` at index `ind`.
"""
function getattrs(attrs::Tuple, pt::P) where {P<:PointRecord}
  map(attr -> readattr(P, attr, pt), attrs)
end
Base.@propagate_inbounds getattrs(
  attrs::Tuple,
  pts::AbstractVector{P},
  ind::Integer,
) where {P<:PointRecord} = getattrs(attrs, pts[ind])

"""
    getattrs(attrs::Tuple, points::AbstractVector{<:PointRecord}, [inds])

Obtain selected attributes of a multiple or all point records in the collection
`points`. This function returns a generator that produces a tuple with the
attribute values for each point. The `inds` can be an `AbstractRange` or `:`
for all points, which is the default.
"""
function getattrs(
  attrs::Tuple,
  pts::AbstractVector{P},
  inds::AbstractRange,
) where {P<:PointRecord}
  @boundscheck checkbounds(pts, inds)
  ((@inbounds getattrs(attrs, pts, ind)) for ind in inds)
end
function getattrs(attrs::Tuple, pts::AbstractVector{<:PointRecord}, ::Colon)
  @inbounds getattrs(attrs, pts, axes(pts, 1))
end

"""
    attribute([f], attr::Val, p::PointRecord)
    attribute([f], attr::Val, points, [inds])

Read the point attribute `attr` from a single point `p` or from a collection
`points`, where `inds` can be a single index, a range of indices, or `:` for
all points, which is the default. This is an internal function that unifies the
functionality of different accessor function for point attributes, such as
`coordinates` and `intensity`. The function `f` is applied to the attribute for
each point. If the point record type does not have the requested attribute,
`missing` is returned instead.
"""
function attribute end
attribute(::Val{F}, args...) where {F} = attribute(identity, Val(F), args...)
function attribute(f, ::Val{F}, pt::P) where {P<:PointRecord,F}
  f(hasfield(P, F) ? getattrs((Val(F),), pt)[1] : missing)
end
function attribute(
  f,
  ::Val{F},
  pts::AbstractVector{P},
  ind::Integer,
) where {P<:PointRecord,F}
  f(hasfield(P, F) ? getattrs((Val(F),), pts, ind)[1] : missing)
end
function attribute(f, ::Val{F}, pts::AbstractVector{P}, inds = :) where {P<:PointRecord,F}
  if hasfield(P, F)
    map(as -> f(as[1]), getattrs((Val(F),), pts, inds))
  else
    Vector{Missing}(undef, length(inds isa Colon ? pts : inds))
  end
end

"""
    coordinates(Integer, p::PointRecord)
    coordinates(Integer, points, inds)

Obtain the “raw” x-, y-, and z-coordinate of one or multiple point records as a
tuple of 32-bit integers. The meaning of these coordinates depends on a scaling
and a coordinate reference system that are external to the point record. The
first argument can also be used to specify a different integer type.
"""
coordinates(::Type{T}, src...) where {T<:Integer} =
  attribute(a -> convert.(T, a), Val(:coords), src...)

"""
    intensity(p::PointRecord)

Obtain the intensity of the pulse return, normalized such that the dynamic
range of the sensor is represented by the range from 0 to 1.

See also: `color_channels`
"""
intensity(src...) = attribute(a -> a / typemax(UInt16), Val(:intensity), src...)

"""
    intensity(Integer, p::PointRecord)

Obtain the “raw” intensity of a point record as a `UInt16`, unless a specific
integer type is passed as the first argument. Values are normalized such that
the dynamic range of the sensor is corresponds to the range from 0 to
`typemax(UInt16)`.
"""
intensity(::Type{T}, src...) where {T<:Integer} =
  attribute(a -> convert(T, a), Val(:intensity), src...)
# note: intensity is optional, but we still return 0 and not missing for type stability

"""
    color_channels(p::PointRecord)

Obtain the intensity associated with each color channel as a tuple of `UInt16`s.
For PDRFs 2, 3, 5, and 7, this returns three values that correspond to the red,
green, and blue channel whereas PDRFs 8 and 10 include a fourth value for the
near infrared channel. Values should be normalized to cover the range
`typemin(UInt16)` to `typemax(UInt16)`. For other PDRFs that do not include
color information `missing` is returned.
"""
color_channels(src...) = attribute(Val(:color_channels), src...)

"""
    scan_angle(p::PointRecord)

Obtain the angle (as a `Float64`) of the laser beam that scanned the point `p`. The value is defined as the angle in degrees relative to the nadir (i.e. corrected for airplane roll), with 0° pointing straight down, negative values towards the left, and positive values towards the right of the flight path. The values range from −180° to +180° in increments of 0.006° for the PDRFs 6–10, and from −90° to +90° in increments of 1° for the legacy PDRFs 0–5.

See also: [`is_edge_of_line`](@ref), [`is_left_to_right`](@ref), [`is_right_to_left`](@ref)
"""
scan_angle(src...) = attribute(normalize_scan_angle, Val(:scan_angle), src...)

function normalize_scan_angle(angle::Int16)
  -30_000 <= angle <= 30_000 ||
    @error "Scan angle outside the valid range of −180° to +180°"
  angle * 0.006
end

function normalize_scan_angle(angle::Int8)
  -90 <= angle <= 90 || @error "Scan angle outside the valid range of −90° to +90°"
  angle * 1.0
end

"""
    scan_angle(Integer, p::PointRecord)

Obtain the “raw” scan angle of a point record as an `Int8` or `Int16` depending
on the point data record format, unless a specific integer type is passed as
the first argument.
"""
scan_angle(::Type{T}, src...) where {T<:Integer} =
  attribute(a -> convert(T, a), Val(:scan_angle), src...)

"""
    gps_time(p::PointRecord)

Obtain the GPS time at which a point was recorded as a `Float64`, or `missing`
if the point record data format does not include a GPS time.

Refer to the `has_adjusted_gps_time` field of [`LAS`](@ref) for the interpretation of the time value.
"""
gps_time(src...) = attribute(Val(:gps_time), src...)

"""
    waveform_packet(p::PointRecord)

Obtain the raw waveform packet of a point record, or `missing` if the point
record data format does not include waveform packets. Note that PointClouds.jl
currently has very limited functionality for handling waveform data.
"""
waveform_packet(src...) = attribute(Val(:waveform_packet), src...)

"""
    source_id([T], p::PointRecord)

Obtain the source ID of a point as a `UInt16`. This may be used to group points
that were recorded in a uniform manner, e.g. during the same flight line.
"""
source_id(::Type{T}, src...) where {T<:Integer} =
  attribute(a -> convert(T, a), Val(:source_id), src...)
source_id(src...) = source_id(Int, src...)

"""
    user_data(p::PointRecord)

Obtain the “user data” byte of a point record as a `UInt8`. This byte is included
in all PDRFs but does not have any standardized meaning.

See also: [`extra_bytes`](@ref)
"""
user_data(src...) = attribute(Val(:user_data), src...)

"""
    extra_bytes(p::PointRecord)

Obtain the “extra bytes” of a point record as a tuple of `UInt8`s. The meaning
of these bytes may be described with a variable-length record.

See also: [`user_data`](@ref)
"""
extra_bytes(src...) = attribute(Val(:extra_bytes), src...)

"""
    return_number([T], p::PointRecord)

Obtain which return of the laser pulse produced the point data record, as a
`UInt8`. Value between 1 and 15 for the PDRFs 6–10, and between 1 and 5 for the
legacy PDRFs 0–5.

See also: [`return_count`](@ref)
"""
return_number(::Type{T}, src...) where {T<:Integer} =
  attribute(data -> convert(T, meta_rnumber(data)), Val(:metadata), src...)
return_number(src...) = return_number(Int, src...)

"""
    return_count([T], p::PointRecord)

Obtain the total number of returns produced by the laser pulse, as a `UInt8`.
Value between 1 and 15 for the PDRFs 6–10, and between 1 and 5 for the legacy
PDRFs 0–5.

See also: [`return_number`](@ref)
"""
return_count(::Type{T}, src...) where {T<:Integer} =
  attribute(data -> convert(T, meta_rcount(data)), Val(:metadata), src...)
return_count(src...) = return_count(Int, src...)

"""
    is_synthetic(p::PointRecord)

Check whether the point is marked as obtained through “synthetic” means (e.g.
photogrammetry) rather than direct measurement with a laser pulse.

See also: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](@ref), [`is_withheld`](@ref)
"""
is_synthetic(src...) = attribute(meta_synthetic, Val(:metadata), src...)

"""
    is_key_point(p::PointRecord)

Check whether the point is marked as a *key point* that should not be removed
when reducing the point density.

See also: [`classification`](@ref), [`is_overlap`](@ref), [`is_synthetic`](@ref), [`is_withheld`](@ref)
"""
is_key_point(src...) = attribute(meta_keypt, Val(:metadata), src...)

"""
    is_withheld(p::PointRecord)

Check whether the point is marked as *withheld*/deleted and should be skipped
in further processing.

See also: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](@ref), [`is_synthetic`](@ref)
"""
is_withheld(src...) = attribute(meta_withheld, Val(:metadata), src...)

"""
    is_overlap(p::PointRecord)

Check whether the point is marked as *overlap*, e.g. of two flight paths. This
is recorded as a classification (class 12) or as a separate flag (PDRFs 6–10
only) to allow for further classification of overlap points.
"""
is_overlap(src...) = attribute(meta_overlap, Val(:metadata), src...)

"""
    scanner_channel([T], p::PointRecord)

Obtain the channel/scanner head of a multi-channel system, as a UInt8 between 0
and 3. This is only supported for the PDRFs 6–10 and returns `missing` for the
legacy PDRFs 0–5.
"""
scanner_channel(::Type{T}, src...) where {T<:Integer} =
  attribute(Val(:metadata), src...) do a
    c = meta_channel(a)
    ismissing(c) ? c : convert(T, c)
  end
scanner_channel(src...) = scanner_channel(Int, src...)

"""
    is_left_to_right(p::PointRecord)

Check whether the scanner mirror was moving left to right relative to the
in-track direction (increasing scan angle) when the point was recorded.

See also: [`is_right_to_left`](@ref), [`is_edge_of_line`](@ref), [`scan_angle`](@ref)
"""
is_left_to_right(src...) = attribute(meta_ltr, Val(:metadata), src...)

"""
    is_right_to_left(p::PointRecord)

Check whether the scanner mirror was moving right to left relative to the
in-track direction (decreasing scan angle) when the point was recorded.

See also: [`is_left_to_right`](@ref), [`is_edge_of_line`](@ref), [`scan_angle`](@ref)
"""
is_right_to_left(src...) = attribute(!meta_ltr, Val(:metadata), src...)

"""
    is_edge_of_line(p::PointRecord)

Check whether the point was recorded at the edge of a scan line.

See also: [`is_left_to_right`](@ref), [`is_right_to_left`](@ref), [`scan_angle`](@ref)
"""
is_edge_of_line(src...) = attribute(meta_edge, Val(:metadata), src...)

"""
    classification([T], p::PointRecord)

Obtain the class that has been assigned to the point data record, as a UInt8 or
the integer type `T`, if specified. Values in the range 0–63 either correspond
to an ASPRS standard point class or are reserved for future standardization,
whereas the meaning of values in the range 64–255 is user definable.

The ASPRS standard point classes are created/never classified (0), unclassified
(1), ground (2), low vegetation (3), medium vegetation (4), high vegetation
(5), building (6), low point/noise (7), water (9), rail (10), road surface
(11), wire-guard/shield (13), wire-conductor/phase (14), transmission tower
(15), wire-structure connector (16), bridge deck (17), high noise (18),
overhead structure (19), ignored ground (20), snow (21), and temporal exclusion
(22).

The legacy PDRFs 0–5 only support values in the range 0–31 and only define
meanings for the classes 0–9, with additional definitions for model key points
(8) and overlap points (12).

See also: [`is_key_point`](@ref), [`is_overlap`](@ref), [`is_synthetic`](@ref), [`is_withheld`](@ref)
"""
classification(::Type{T}, src...) where {T<:Integer} =
  attribute(a -> convert(T, meta_class(a)), Val(:metadata), src...)
classification(src...) = classification(Int, src...)

# decode metadata bits for newer formats
meta_rnumber(data::NTuple{3}) = data[1] & 0b00001111 # bits 0–3
meta_rcount(data::NTuple{3}) = (data[1] & 0b11110000) >> 4 # bits 4–7
meta_synthetic(data::NTuple{3}) = !iszero(data[2] & 0b00000001) # bit 0
meta_keypt(data::NTuple{3}) = !iszero(data[2] & 0b00000010) # bit 1
meta_withheld(data::NTuple{3}) = !iszero(data[2] & 0b00000100) # bit 2
meta_overlap(data::NTuple{3}) = !iszero(data[2] & 0b00001000) || meta_class(data) == 12 # bit 3
meta_channel(data::NTuple{3}) = (data[2] & 0b00110000) >> 4 # bits 4–5
meta_ltr(data::NTuple{3}) = !iszero(data[2] & 0b01000000) # bit 6
meta_edge(data::NTuple{3}) = !iszero(data[2] & 0b10000000) # bit 7
meta_class(data::NTuple{3}) = data[3] # bits 0–7

# decode metadata bits for legacy formats
meta_rnumber(data::NTuple{2}) = data[1] & 0b00000111 # bits 0–2
meta_rcount(data::NTuple{2}) = (data[1] & 0b00111000) >> 3 # bits 3–5
meta_ltr(data::NTuple{2}) = !iszero(data[1] & 0b01000000) # bit 6
meta_edge(data::NTuple{2}) = !iszero(data[1] & 0b10000000) # bit 7
meta_class(data::NTuple{2}) = data[2] & 0b00011111 # bits 0–4
meta_synthetic(data::NTuple{2}) = !iszero(data[2] & 0b00100000) # bit 5
meta_keypt(data::NTuple{2}) = !iszero(data[2] & 0b01000000) # bit 6
meta_withheld(data::NTuple{2}) = !iszero(data[2] & 0b10000000) # bit 7
meta_overlap(data::NTuple{2}) = meta_class(data) == 12
meta_channel(data::NTuple{2}) = missing # unavailable for legacy points

function Base.show(io::Base.IO, pt::UnknownPointRecord)
  bytes = map(b -> string(b; base = 16, pad = 2), pt.data)
  if get(io, :typeinfo, Any) == typeof(pt)
    print(io, "0x", join(bytes))
  else
    print(io, typeof(pt), "(0x", join(bytes), ")")
  end
end

function Base.show(io::Base.IO, pt::PointRecord{F,N}) where {F,N}
  io = IOContext(io, :compact => true) # to make floats more reasonable
  if get(io, :typeinfo, Any) != typeof(pt)
    print(io, "PointRecord{", F, iszero(N) ? "" : ",$N", "}")
  end
  coords = coordinates(Integer, pt)
  print(io, "(X = ", coords[1], ", Y = ", coords[2], ", Z = ", coords[3])
  iszero(intensity(pt)) || print(io, ", intensity = ", intensity(pt))
  print(io, ", return = ", return_number(pt), "/", return_count(pt))
  print(io, ", classification = ", classification(pt))
  flags = []
  push!(flags, is_left_to_right(pt) ? "left-to-right" : "right-to-left")
  is_edge_of_line(pt) && push!(flags, "edge of flight line")
  is_synthetic(pt) && push!(flags, "synthetic")
  is_key_point(pt) && push!(flags, "key-point")
  is_withheld(pt) && push!(flags, "withheld")
  print(io, ", flags = [", join(flags, ", "), "]")

  # if angle is defined as integer, print as Int64 so it has no decimal point
  # but abs(pt) still works for typemin(Int16)
  angle = pt isa LegacyPointRecord ? Int64(pt.scan_angle) : scan_angle(pt)
  angle_prefix = angle > 0 ? "+" : angle < 0 ? "−" : ""
  print(io, ", scan angle = ", angle_prefix, abs(angle), '°')

  # format-specific fields
  channel = scanner_channel(pt)
  ismissing(channel) || print(io, ", scanner channel = ", channel)
  gps = gps_time(pt)
  ismissing(gps) || print(io, ", GPS time = ", gps)
  color = color_channels(pt)
  ismissing(color) || print(io, ", color = ", Int.(color))
  waveform = waveform_packet(pt)
  ismissing(waveform) || print(io, ", waveform packet = ", waveform)

  iszero(user_data(pt)) || print(io, ", user data = ", user_data(pt))
  print(io, ", source ID = ", source_id(pt))
  if !iszero(N)
    bytes = map(b -> string(b; base = 16, pad = 2), extra_bytes(pt))
    print(io, ", extra bytes = 0x", join(bytes))
  end
  print(io, ")")
end

point_record_number(::Type{<:PointRecord{F}}) where {F} = F
point_record_nonstandard_bytes(::Type{<:PointRecord{F,N}}) where {F,N} = N
point_record_bytes(T::Type{<:PointRecord}) = sum(sizeof(t) for t in fieldtypes(T))

function point_record_description(::Type{<:PointRecord{F,N}}) where {F,N}
  string("PDRF ", F, iszero(N) ? "" : " with $N extra byte" * 's'^(N > 1))
end
point_record_description(::Type{<:PointRecord{F}}) where {F} = string("PDRF ", F)
function point_record_description(::Type{UnknownPointRecord{F,N}}) where {F,N}
  "unsupported $N-byte PDRF $F"
end

abstract_record_type(::Type{<:PointRecord{F,N}}) where {F,N} = PointRecord{F,N}
abstract_record_type(::Type{<:PointRecord{F,0}}) where {F} = PointRecord{F}
abstract_record_type(::Type{UnknownPointRecord{F,N}}) where {F,N} = UnknownPointRecord{F,N}

function point_record_type(::Type{T}) where {F,N,T<:PointRecord{F,N}}
  # convert to a concrete type
  isconcretetype(T) ? T : point_record_type(F){N}
end

point_record_type(::Type{T}) where {F,T<:PointRecord{F}} = point_record_type(F){0}

function point_record_type(number::Integer)
  number in 0:10 || throw(ArgumentError("Unknown Point Data Record Format: $number"))
  (
    PointRecord0,
    PointRecord1,
    PointRecord2,
    PointRecord3,
    PointRecord4,
    PointRecord5,
    PointRecord6,
    PointRecord7,
    PointRecord8,
    PointRecord9,
    PointRecord10,
  )[number+1]
end

function point_record_type(number, bytes)
  if number in 0:10
    T = point_record_type(number)
    nextra = bytes - point_record_bytes(T{0})
    nextra >= 0 || error("Record length $bytes is too small for point format $number")
    T{Int(nextra)}
  else
    @error "Unknown Point Data Record Format: $number"
    UnknownPointRecord{Int(number),Int(bytes)}
  end
end

# pick non-zero offset if values are far from origin
function pick_offset(values)
  minval, maxval = extrema(values)
  spread = maxval - minval # always >= 0
  if minval > spread || maxval < -spread
    s = sign(minval) # min & max have same sign
    c = abs(minval + maxval) / 2 # midpoint, always > 0
    p = 10^floor(log10(c)) # power of 10 below midpoint
    Float64(s * p) * (2 * mod(c, p) < p ? 1 : 10) # round up if required
  else
    zero(Float64)
  end
end

function pick_scale(values, offset)
  minval, maxval = extrema(values)
  range = max(abs(minval - offset), abs(maxval - offset)) # >= 0
  min_scale = max(range / typemax(Int32), 1e-9) # avoid extremely small scales
  10^ceil(log10(min_scale))
end

pick_scaling(values, scale::Real, offset::Real) = (scale, offset)
pick_scaling(values, scale::Real, ::Nothing) = (scale, pick_offset(values))
pick_scaling(values, ::Nothing, offset::Real) = (pick_scale(values, offset), offset)

function pick_scaling(values, ::Nothing, ::Nothing)
  values = extrema(values) # only compute once
  offset = pick_offset(values)
  (pick_scale(values, offset), offset)
end

function pick_scalings(coords; scale, offset)
  scalings = pick_scaling.(coords, scale, offset)
  (coord_scale = first.(scalings), coord_offset = last.(scalings))
end

function las_points(::Type{T}, attrs; coord_scale, coord_offset) where {T<:PointRecord}
  @assert isconcretetype(T) || return las_points(
    point_record_type(T),
    attrs;
    coord_scale = coord_scale,
    coord_offset = coord_offset,
  )
  @assert haskey(attrs, :x)
  @assert haskey(attrs, :y)
  @assert haskey(attrs, :z)
  allequal(length.(values(attrs))) || error("Point attributes do not have the same length")
  points = Vector{T}(undef, length(attrs.x))
  @assert all(axes(a) == axes(points) for a in values(attrs))
  attrs = normalized_attributes(T, attrs) # combines encoded metadata
  for ind in eachindex(points)
    coords = (attrs.x[ind], attrs.y[ind], attrs.z[ind])
    int_coords = round.(Int32, (coords .- coord_offset) ./ coord_scale)
    fields = map(fieldnames(T)) do f
      F = fieldtype(T, f)
      if f == :coords
        int_coords
      elseif haskey(attrs, f)
        convert(F, attrs[f][ind])
      elseif f == :metadata
        T <: LegacyPointRecord ? (0x0, 0x0) : (0x0, 0x0, 0x0)
      elseif f == :extra_bytes
        ntuple(_ -> 0x0, point_record_nonstandard_bytes(T))
      else
        zero(F)
      end
    end
    points[ind] = T(fields...)
  end

  points
end

function metadata_sizes(::Type{<:PointRecord})
  (
    return_number = 4,
    return_count = 4,
    is_synthetic = 1,
    is_key_point = 1,
    is_withheld = 1,
    is_overlap = 1,
    scanner_channel = 2,
    is_left_to_right = 1,
    is_edge_of_line = 1,
    classification = 8,
  )
end

function metadata_sizes(::Type{<:LegacyPointRecord})
  (
    return_number = 3,
    return_count = 3,
    is_left_to_right = 1,
    is_edge_of_line = 1,
    classification = 5,
    is_synthetic = 1,
    is_key_point = 1,
    is_withheld = 1,
  )
end

metadata_sizes(pts::AbstractArray) = metadata_sizes(eltype(pts))
@assert sum(metadata_sizes(PointRecord{6})) == 24
@assert sum(metadata_sizes(PointRecord{1})) == 16

function normalized_attributes(pts, attrs)
  # note: pts can be arrary or just the point type
  ATTRS = metadata_sizes(pts)
  # rename left-to-right
  ltr, rtl = :is_left_to_right, :is_right_to_left
  encoded = NamedTuple(
    k == rtl ? ltr => .!v : k => v for
    (k, v) in pairs(attrs) if haskey(ATTRS, k) || k == rtl
  )
  isempty(encoded) && return attrs
  rest = NamedTuple(k => v for (k, v) in pairs(attrs) if !haskey(ATTRS, k))

  (; rest..., metadata = encode_metadata(pts, encoded))
end

pad_metadata(::Type{<:PointRecord}, _) = zero(UInt32)
function pad_metadata(pts::AbstractVector{<:PointRecord}, ind)
  bytes = attribute(Val(:metadata), pts, ind)
  padding = ntuple(_ -> 0x0, 4 - fieldcount(typeof(bytes)))
  reinterpret(UInt32, (bytes..., padding...))
end
unpad_metadata(::AbstractVector{P}, data) where {P<:PointRecord} = unpad_metadata(P, data)
function unpad_metadata(::Type{P}, data) where {P<:PointRecord}
  N = fieldcount(fieldtype(P, :metadata))
  reinterpret(NTuple{4,UInt8}, data)[1:N]
end

function encode_metadata(pts::Union{AbstractVector,Type}, attrs::NamedTuple)
  # note: pts can be array or just the point type
  ATTRS = metadata_sizes(pts)

  # make sure lengths are compatible
  ptcount = length(first(attrs))
  @assert allequal(map(length, attrs))
  pts isa AbstractVector && @assert length(pts) == ptcount

  # make sure metadata fields have the correct type
  for (key, vals) in pairs(attrs)
    haskey(ATTRS, key) || error("Unknown point attribute: $key")
    T = ATTRS[key] == 1 ? Bool : Integer
    # we probably want to allow any type that can be converted, not just the exact type
    #eltype(vals) <: T || error("Invalid element type $(eltype(vals)) for `$key` (expected $T)")
    if T == Integer
      minval, maxval = extrema(vals)
      attrmax = (1 << ATTRS[key])
      0 <= minval <= maxval < attrmax ||
        error("Values for `$key` must be in the range [0, $attrmax)")
    end
  end

  # find position of metadata attributes
  findshift(k) = sum(values(ATTRS)[1:findfirst(==(k), keys(ATTRS))-1]; init = 0)
  shifts = NamedTuple(k => findshift(k) for k in keys(attrs))
  masks =
    NamedTuple(k => ~(((0x1 << ATTRS[k]) - UInt32(1)) << shifts[k]) for k in keys(attrs))

  map(1:ptcount) do ind
    attr = pad_metadata(pts, ind)
    for (key, vals) in pairs(attrs)
      attr = (attr & masks[key]) | (UInt32(vals[ind]) << shifts[key])
    end
    #reinterpret(NTuple{4,UInt8}, attr)[1:(eltype(p]
    unpad_metadata(pts, attr)
  end
end

function update(pt::PointRecord, attrs::NamedTuple)
  attrs = map(fieldnames(typeof(pt))) do f
    haskey(attrs, f) ? attrs[f] : getfield(pt, f)
  end
  typeof(pt)(attrs...)
end

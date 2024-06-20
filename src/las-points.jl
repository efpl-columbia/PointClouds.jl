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
  - point record classification: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](#) *(all PDRFs, based on classification for PDRF 0–5)*, [`is_synthetic`](@ref), [`is_withheld`](@ref)
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{2,UInt8}
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
  attributes::NTuple{3,UInt8}
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
  attributes::NTuple{3,UInt8}
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
  attributes::NTuple{3,UInt8}
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
  attributes::NTuple{3,UInt8}
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
  attributes::NTuple{3,UInt8}
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

# simple accessors for fields that always exist
# note: intensity is optional, but we still return 0 and not missing for type stability
integer_coordinates(pt) = pt.coords # TODO: remove
integer_scan_angle(pt) = scan_angle(Integer, pt) # TODO: remove
integer_scan_angle(type, pt) = scan_angle(type, pt) # TODO: remove

encoded_attributes(pt) = pt.attributes
function encoded_attributes(::Type{T}, pt) where {T}
  @assert typeof(pt.attributes) == T
  pt.attributes
end

"""
    coordinates(Integer, p::PointRecord)

Obtain the “raw” x-, y-, and z-coordinate of a point record as a tuple of
32-bit integers. Pass `Int` as the first argument for 64-bit integers.

See also: `getscaling`
"""
coordinates(::Type{T}, pt) where {T<:Integer} = convert.(T, pt.coords)

"""
    intensity(p::PointRecord)

Obtain the intensity of the pulse return, normalized such that the dynamic
range of the sensor is represented by the range from 0 to 1.

See also: `color_channels`
"""
intensity(pt) = intensity(UInt16, pt) / typemax(UInt16)

"""
    intensity(Integer, p::PointRecord)

Obtain the “raw” intensity of a point record as a `UInt16`, unless a specific
integer type is passed as the first argument. Values are normalized such that
the dynamic range of the sensor is corresponds to the range from 0 to
`typemax(UInt16)`.
"""
intensity(::Type{T}, pt) where {T<:Integer} = convert(T, intensity(UInt16, pt))
intensity(::Type{UInt16}, pt) = pt.intensity

"""
    color_channels(p::PointRecord)

Obtain the intensity associated with each color channel as a tuple of `UInt16`s.
For PDRFs 2, 3, 5, and 7, this returns three values that correspond to the red,
green, and blue channel whereas PDRFs 8 and 10 include a fourth value for the
near infrared channel. Values should be normalized to cover the range
`typemin(UInt16)` to `typemax(UInt16)`. For other PDRFs that do not include
color information `missing` is returned.
"""
color_channels(pt) = hasfield(typeof(pt), :color_channels) ? pt.color_channels : missing
function color_channels(::Type{T}, pt) where {T}
  @assert typeof(pt.color_channels) == T
  pt.color_channels
end

"""
    scan_angle(p::PointRecord)

Obtain the angle (as a `Float64`) of the laser beam that scanned the point `p`. The value is defined as the angle in degrees relative to the nadir (i.e. corrected for airplane roll), with 0° pointing straight down, negative values towards the left, and positive values towards the right of the flight path. The values range from −180° to +180° in increments of 0.006° for the PDRFs 6–10, and from −90° to +90° in increments of 1° for the legacy PDRFs 0–5.

See also: [`is_edge_of_line`](@ref), [`is_left_to_right`](@ref), [`is_right_to_left`](@ref)
"""
function scan_angle(pt::PointRecord)
  -30_000 <= pt.scan_angle <= 30_000 ||
    @error "Scan angle outside the valid range of −180° to +180°"
  pt.scan_angle * 0.006
end
function scan_angle(pt::LegacyPointRecord)
  -90 <= pt.scan_angle <= 90 || @error "Scan angle outside the valid range of −90° to +90°"
  pt.scan_angle * 1.0
end

"""
    scan_angle(Integer, p::PointRecord)

Obtain the “raw” scan angle of a point record as an `Int8` or `Int16` depending
on the point data record format, unless a specific integer type is passed as
the first argument.
"""
scan_angle(::Type{T}, pt) where {T<:Integer} = convert(T, pt.scan_angle)

"""
    gps_time(p::PointRecord)

Obtain the GPS time at which a point was recorded as a `Float64`, or `missing`
if the point record data format does not include a GPS time.

Refer to the `has_adjusted_gps_time` field of [`LAS`](@ref) for the interpretation of the time value.
"""
gps_time(pt) = hasfield(typeof(pt), :gps_time) ? pt.gps_time : missing

"""
    waveform_packet(p::PointRecord)

Obtain the raw waveform packet of a point record, or `missing` if the point
record data format does not include waveform packets. Note that PointClouds.jl
currently has very limited functionality for handling waveform data.
"""
waveform_packet(pt) = hasfield(typeof(pt), :waveform_packet) ? pt.waveform_packet : missing

"""
    source_id(p::PointRecord)

Obtain the source ID of a point as a `UInt16`. This may be used to group points
that were recorded in a uniform manner, e.g. during the same flight line.
"""
source_id(pt) = pt.source_id

"""
    user_data(p::PointRecord)

Obtain the “user data” byte of a point record as a `UInt8`. This byte is included
in all PDRFs but does not have any standardized meaning.

See also: [`extra_bytes`](@ref)
"""
user_data(pt) = pt.user_data

"""
    extra_bytes(p::PointRecord)

Obtain the “extra bytes” of a point record as a tuple of `UInt8`s. The meaning
of these bytes may be described with a variable-length record.

See also: [`user_data`](@ref)
"""
extra_bytes(pt) = pt.extra_bytes
extra_bytes(::Type{T}, pt) where {T} = (@assert typeof(pt.extra_bytes) == T; pt.extra_bytes)

# decode attribute bits for newer formats
# TODO: decide whether classification(pt) == 12 should also be treated as overlap
"""
    return_number(p::PointRecord)

Obtain which return of the laser pulse produced the point data record, as a
`UInt8`. Value between 1 and 15 for the PDRFs 6–10, and between 1 and 5 for the
legacy PDRFs 0–5.

See also: [`return_count`](@ref)
"""
return_number(pt::PointRecord) = pt.attributes[1] & 0b00001111 # bits 0–3

"""
    return_count(p::PointRecord)

Obtain the total number of returns produced by the laser pulse, as a `UInt8`.
Value between 1 and 15 for the PDRFs 6–10, and between 1 and 5 for the legacy
PDRFs 0–5.

See also: [`return_number`](@ref)
"""
return_count(pt::PointRecord) = (pt.attributes[1] & 0b11110000) >> 4 # bits 4–7

"""
    is_synthetic(p::PointRecord)

Check whether the point is marked as obtained through “synthetic” means (e.g.
photogrammetry) rather than direct measurement with a laser pulse.

See also: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](@ref), [`is_withheld`](@ref)
"""
is_synthetic(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000001) # bit 0

"""
    is_key_point(p::PointRecord)

Check whether the point is marked as a *key point* that should not be removed
when reducing the point density.

See also: [`classification`](@ref), [`is_overlap`](@ref), [`is_synthetic`](@ref), [`is_withheld`](@ref)
"""
is_key_point(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000010) # bit 1

"""
    is_withheld(p::PointRecord)

Check whether the point is marked as *withheld*/deleted and should be skipped
in further processing.

See also: [`classification`](@ref), [`is_key_point`](@ref), [`is_overlap`](@ref), [`is_synthetic`](@ref)
"""
is_withheld(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000100) # bit 2

"""
    is_overlap(p::PointRecord)

Check whether the point is marked as *overlap*, e.g. of two flight paths. This
is recorded as a classification (class 12) or as a separate flag (PDRFs 6–10
only) to allow for further classification of overlap points.
"""
is_overlap(pt::PointRecord) =
  classification(pt) == 12 || !iszero(pt.attributes[2] & 0b00001000) # bit 3

"""
    scanner_channel(p::PointRecord)

Obtain the channel/scanner head of a multi-channel system, as a UInt8 between 0
and 3. This is only supported for the PDRFs 6–10 and returns `missing` for the
legacy PDRFs 0–5.
"""
scanner_channel(pt::PointRecord) = (pt.attributes[2] & 0b00110000) >> 4 # bits 4–5

"""
    is_left_to_right(p::PointRecord)

Check whether the scanner mirror was moving left to right relative to the
in-track direction (increasing scan angle) when the point was recorded.

See also: [`is_right_to_left`](@ref), [`is_edge_of_line`](@ref), [`scan_angle`](@ref)
"""
is_left_to_right(pt::PointRecord) = !iszero(pt.attributes[2] & 0b01000000) # bit 6

"""
    is_right_to_left(p::PointRecord)

Check whether the scanner mirror was moving right to left relative to the
in-track direction (decreasing scan angle) when the point was recorded.

See also: [`is_left_to_right`](@ref), [`is_edge_of_line`](@ref), [`scan_angle`](@ref)
"""
is_right_to_left(pt::PointRecord) = !is_left_to_right(pt)

"""
    is_edge_of_line(p::PointRecord)

Check whether the point was recorded at the edge of a scan line.

See also: [`is_left_to_right`](@ref), [`is_right_to_left`](@ref), [`scan_angle`](@ref)
"""
is_edge_of_line(pt::PointRecord) = !iszero(pt.attributes[2] & 0b10000000) # bit 7

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
classification(::Type{T}, pt::PointRecord) where {T<:Integer} = convert(T, pt.attributes[3]) # bits 0–7
classification(pt::PointRecord) = classification(UInt8, pt)

# decode attribute bits for legacy formats
return_number(pt::LegacyPointRecord) = pt.attributes[1] & 0b00000111 # bits 0–2
return_count(pt::LegacyPointRecord) = (pt.attributes[1] & 0b00111000) >> 3 # bits 3–5
is_left_to_right(pt::LegacyPointRecord) = !iszero(pt.attributes[1] & 0b01000000) # bit 6
is_right_to_left(pt::LegacyPointRecord) = !is_left_to_right(pt)
is_edge_of_line(pt::LegacyPointRecord) = !iszero(pt.attributes[1] & 0b10000000) # bit 7
function classification(::Type{T}, pt::LegacyPointRecord) where {T<:Integer}
  convert(T, pt.attributes[2] & 0b00011111) # bits 0–4
end
is_synthetic(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b00100000) # bit 5
is_key_point(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b01000000) # bit 6
is_withheld(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b10000000) # bit 7
is_overlap(pt::LegacyPointRecord) = classification(pt) == 12
scanner_channel(::LegacyPointRecord) = missing

core_fields(pt) = core_fields(typeof(pt), pt)
function core_fields(::Type{<:LegacyPointRecord}, pt)
  (
    integer_coordinates(pt),
    intensity(Integer, pt),
    encoded_attributes(NTuple{2,UInt8}, pt),
    integer_scan_angle(Int8, pt),
    user_data(pt),
    source_id(pt),
  )
end
function core_fields(::Type{<:PointRecord}, pt)
  (
    integer_coordinates(pt),
    intensity(Integer, pt),
    encoded_attributes(NTuple{3,UInt8}, pt),
    user_data(pt),
    integer_scan_angle(Int16, pt),
    source_id(pt),
    gps_time(pt),
  )
end

distinct_fields(pt) = distinct_fields(typeof(pt), pt)
distinct_fields(::Type{<:PointRecord{0}}, pt) = ()
distinct_fields(::Type{<:PointRecord{1}}, pt) = (gps_time(pt),)
distinct_fields(::Type{<:PointRecord{2}}, pt) = (color_channels(NTuple{3,UInt16}, pt),)
function distinct_fields(::Type{<:PointRecord{3}}, pt)
  (gps_time(pt), color_channels(NTuple{3,UInt16}, pt))
end
distinct_fields(::Type{<:PointRecord{4}}, pt) = (gps_time(pt), waveform_packet(pt))
function distinct_fields(::Type{<:PointRecord{5}}, pt)
  (gps_time(pt), color_channels(NTuple{3,UInt16}, pt), waveform_packet(pt))
end
distinct_fields(::Type{<:PointRecord{6}}, pt) = ()
distinct_fields(::Type{<:PointRecord{7}}, pt) = (color_channels(NTuple{3,UInt16}, pt),)
distinct_fields(::Type{<:PointRecord{8}}, pt) = (color_channels(NTuple{4,UInt16}, pt),)
distinct_fields(::Type{<:PointRecord{9}}, pt) = (waveform_packet(pt),)
function distinct_fields(::Type{<:PointRecord{10}}, pt)
  (color_channels(NTuple{4,UInt16}, pt), waveform_packet(pt))
end

all_fields(pt) = all_fields(typeof(pt), pt)
function all_fields(T::Type{<:PointRecord{F,N}}, pt) where {F,N}
  (core_fields(T, pt)..., distinct_fields(T, pt)..., extra_bytes(NTuple{N,UInt8}, pt))
end
all_fields(::Type{<:UnknownPointRecord}, pt) = (pt.data,)

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
  coords = integer_coordinates(pt)
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
  ismissing(color) || print(io, ", color = ", color)
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

integer_coordinates(io::Base.IO) = ntuple(_ -> read(io, Int32), 3)
intensity(::Type{UInt16}, io::Base.IO) = read(io, UInt16)
function encoded_attributes(::Type{NTuple{N,UInt8}}, io::Base.IO) where {N}
  ntuple(_ -> read(io, UInt8), N)
end
integer_scan_angle(::Type{T}, io::Base.IO) where {T<:Union{Int8,Int16}} = read(io, T)
user_data(io::Base.IO) = read(io, UInt8)
source_id(io::Base.IO) = read(io, UInt16)
gps_time(io::Base.IO) = read(io, Float64)
function waveform_packet(io::Base.IO)
  map(read(io, T), (UInt8, UInt64, UInt32, Float32, Float32, Float32, Float32))
end
function color_channels(::Type{NTuple{N,UInt16}}, io::Base.IO) where {N}
  @assert N == 3 || N == 4
  ntuple(_ -> read(io, UInt16), N)
end
function extra_bytes(::Type{NTuple{N,UInt8}}, io::Base.IO) where {N}
  ntuple(_ -> read(io, UInt8), N)
end

# do not try to convert point to itself (needed to override method below)
Base.convert(::Type{T}, pt::T) where {T<:PointRecord} = pt
Base.convert(::Type{T}, pt) where {T<:PointRecord} = T(all_fields(T, pt)...)

function Base.read(io::Base.IO, ::Type{UnknownPointRecord{F,N}}) where {F,N}
  UnknownPointRecord{F,N}(ntuple(_ -> read(io, UInt8), N))
end

Base.read(io::Base.IO, ::Type{T}) where {T<:PointRecord} = T(all_fields(T, io)...)

function Base.write(io::Base.IO, pt::T) where {T<:PointRecord}
  for field in all_fields(pt)
    if field isa Tuple
      foreach(val -> write(io, val), field)
    else
      write(io, field)
    end
  end
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
  attrs = normalized_attributes(T, attrs) # combines encoded attributes
  for ind in eachindex(points)
    coords = (attrs.x[ind], attrs.y[ind], attrs.z[ind])
    int_coords = round.(Int32, (coords .- coord_offset) ./ coord_scale)
    fields = map(fieldnames(T)) do f
      F = fieldtype(T, f)
      if f == :coords
        int_coords
      elseif haskey(attrs, f)
        convert(F, attrs[f][ind])
      elseif f == :attributes
        T <: LegacyPointRecord ? (0x0, 0x0) : (0x0, 0x0, 0x0)
      elseif f == :extra_bytes
        ntuple(_ -> 0x0, point_record_nonstandard_bytes(T))
      else
        zero(F)
      end
    end
    points[ind] = T(fields...)
    #=
    intensity = zero(UInt16)
    attributes = (zero(UInt8), zero(UInt8), zero(UInt8))
    user_data = zero(UInt8)
    scan_angle = zero(Int16)
    source_id = zero(UInt16)
    gps_time = zero(Float64)
    extra_bytes = ()
    points[ind] = T(int_coords, intensity, attributes, user_data, scan_angle, source_id, gps_time, extra_bytes)=#
  end

  points
end

function encode_attributes_unused(::Type{T}, attrs::NamedTuple) where {T<:PointRecord}
  isconcretetype(T) || return encode_attributes(point_record_type(T), attrs)
  @assert allequal(length.(values(attrs)))
  count = length(first(attrs))
end

function attribute_sizes(::Type{<:PointRecord})
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

function attribute_sizes(::Type{<:LegacyPointRecord})
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

attribute_sizes(pts::AbstractArray) = attribute_sizes(eltype(pts))
@assert sum(attribute_sizes(PointRecord{6})) == 24
@assert sum(attribute_sizes(PointRecord{1})) == 16

function normalized_attributes(pts, attrs)
  # note: pts can be arrary or just the point type
  ATTRS = attribute_sizes(pts)
  # rename left-to-right
  ltr, rtl = :is_left_to_right, :is_right_to_left
  encoded = NamedTuple(
    k == rtl ? ltr => .!v : k => v for
    (k, v) in pairs(attrs) if haskey(ATTRS, k) || k == rtl
  )
  isempty(encoded) && return attrs
  rest = NamedTuple(k => v for (k, v) in pairs(attrs) if !haskey(ATTRS, k))

  (; rest..., attributes = encode_attributes(pts, encoded))
end

pad_attributes(::Type{<:PointRecord}, _) = zero(UInt32)
function pad_attributes(pts::AbstractVector{<:PointRecord}, ind)
  reinterpret(UInt32, (encoded_attributes(NTuple{3,UInt8}, pts[ind])..., 0x0))
end
function pad_attributes(pts::AbstractVector{<:LegacyPointRecord}, ind)
  reinterpret(UInt32, (encoded_attributes(NTuple{2,UInt8}, pts[ind])..., 0x0, 0x0))
end
unpad_attributes(pts::AbstractVector, ind) = unpad_attributes(eltype(pts), ind)
unpad_attributes(T::Type{<:PointRecord}, attr) = reinterpret(NTuple{4,UInt8}, attr)[1:3]
function unpad_attributes(T::Type{<:LegacyPointRecord}, attr)
  reinterpret(NTuple{4,UInt8}, attr)[1:2]
end

function encode_attributes(pts::Union{AbstractVector,Type}, attrs::NamedTuple)
  # note: pts can be array or just the point type
  ATTRS = attribute_sizes(pts)

  # make sure lengths are compatible
  ptcount = length(first(attrs))
  @assert allequal(map(length, attrs))
  pts isa AbstractVector && @assert length(pts) == ptcount

  # make sure attributes have the correct type
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

  # find position of attributes
  findshift(k) = sum(values(ATTRS)[1:findfirst(==(k), keys(ATTRS))-1]; init = 0)
  shifts = NamedTuple(k => findshift(k) for k in keys(attrs))
  masks =
    NamedTuple(k => ~(((0x1 << ATTRS[k]) - UInt32(1)) << shifts[k]) for k in keys(attrs))

  map(1:ptcount) do ind
    attr = pad_attributes(pts, ind)
    for (key, vals) in pairs(attrs)
      attr = (attr & masks[key]) | (UInt32(vals[ind]) << shifts[key])
    end
    #reinterpret(NTuple{4,UInt8}, attr)[1:(eltype(p]
    unpad_attributes(pts, attr)
  end
end

function update(pt::PointRecord, attrs::NamedTuple)
  attrs = map(fieldnames(typeof(pt))) do f
    haskey(attrs, f) ? attrs[f] : getfield(pt, f)
  end
  typeof(pt)(attrs...)
end

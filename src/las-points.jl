abstract type PointRecord{F,N} end
abstract type LegacyPointRecord{F,N} <: PointRecord{F,N} end

const WaveformPacket = Tuple{UInt8,UInt64,UInt32,Float32,Float32,Float32,Float32}

struct UnknownPointRecord{F,N} <: PointRecord{F,N}
  data::NTuple{N,UInt8}
end

struct PointRecord0{N} <: LegacyPointRecord{0,N}
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

struct PointRecord1{N} <: LegacyPointRecord{1,N}
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

struct PointRecord2{N} <: LegacyPointRecord{2,N}
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

struct PointRecord3{N} <: LegacyPointRecord{3,N}
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

struct PointRecord4{N} <: LegacyPointRecord{4,N}
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

struct PointRecord5{N} <: LegacyPointRecord{5,N}
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
integer_coordinates(pt) = pt.coords
intensity(pt) = pt.intensity
encoded_attributes(pt) = pt.attributes
integer_scan_angle(pt) = pt.scan_angle
user_data(pt) = pt.user_data
source_id(pt) = pt.source_id
extra_bytes(pt) = pt.extra_bytes

# return missing for formats that do not have a field
gps_time(pt) = hasfield(typeof(pt), :gps_time) ? pt.gps_time : missing
color_channels(pt) = hasfield(typeof(pt), :color_channels) ? pt.color_channels : missing
waveform_packet(pt) = hasfield(typeof(pt), :waveform_packet) ? pt.waveform_packet : missing

# decode attribute bits for legacy formats
return_number(pt::LegacyPointRecord) = pt.attributes[1] & 0b00000111 # bits 0–2
return_count(pt::LegacyPointRecord) = (pt.attributes[1] & 0b00111000) >> 3 # bits 3–5
is_left_to_right(pt::LegacyPointRecord) = !iszero(pt.attributes[1] & 0b01000000) # bit 6
is_right_to_left(pt::LegacyPointRecord) = !is_left_to_right(pt)
is_edge_of_line(pt::LegacyPointRecord) = !iszero(pt.attributes[1] & 0b10000000) # bit 7
classification(pt::LegacyPointRecord) = pt.attributes[2] & 0b00011111 # bits 0–4
is_synthetic(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b00100000) # bit 5
is_key_point(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b01000000) # bit 6
is_withheld(pt::LegacyPointRecord) = !iszero(pt.attributes[2] & 0b10000000) # bit 7
is_overlap(pt::LegacyPointRecord) = classification(pt) == 12

# decode attribute bits for newer formats
# TODO: decide whether classification(pt) == 12 should also be treated as overlap
return_number(pt::PointRecord) = pt.attributes[1] & 0b00001111 # bits 0–3
return_count(pt::PointRecord) = (pt.attributes[1] & 0b11110000) >> 4 # bits 4–7
is_synthetic(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000001) # bit 0
is_key_point(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000010) # bit 1
is_withheld(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00000100) # bit 2
is_overlap(pt::PointRecord) = !iszero(pt.attributes[2] & 0b00001000) # bit 3
scanner_channel(pt::PointRecord) = (pt.attributes[2] & 0b00110000) >> 4 # bits 4–5
is_left_to_right(pt::PointRecord) = !iszero(pt.attributes[2] & 0b01000000) # bit 6
is_right_to_left(pt::PointRecord) = !is_left_to_right(pt)
is_edge_of_line(pt::PointRecord) = !iszero(pt.attributes[2] & 0b10000000) # bit 7
classification(pt::PointRecord) = pt.attributes[3] # bits 0–7

# provide access to rescaled scan angle
function scan_angle(pt::LegacyPointRecord)
  -90 <= pt.scan_angle <= 90 || @error "Scan angle outside the valid range of −90° to +90°"
  pt.scan_angle * 1.0
end
function scan_angle(pt::PointRecord)
  -30_000 <= pt.scan_angle <= 30_000 || @error "Scan angle outside the valid range of −180° to +180°"
  pt.scan_angle * 0.006
end

function Base.show(io::Base.IO, ::Type{<:PointRecord{F,N}}) where {F,N}
  print(io, "PointRecord{", F, iszero(N) ? "" : ",$N", "}")
end

function Base.show(io::Base.IO, pt::PointRecord{F,N}) where {F,N}
  io = IOContext(io, :compact => true) # to make floats more reasonable
  get(io, :typeinfo, Any) == typeof(pt) || show(io, typeof(pt))
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
  print(io, ", attributes = [", join(flags, ", "), "]")

  # if angle is defined as integer, print as Int64 so it has no decimal point
  # but abs(pt) still works for typemin(Int16)
  angle = pt isa LegacyPointRecord ? Int64(pt.scan_angle) : scan_angle(pt)
  angle_prefix = angle > 0 ? "+" : angle < 0 ? "−" : ""
  print(io, ", scan angle = ", angle_prefix, abs(angle), '°')

  # format-specific fields
  gps = gps_time(pt)
  if !ismissing(gps)
    print(io, ", GPS time = ", gps)
  end
  color = color_channels(pt)
  if !ismissing(color)
    print(io, ", color = #")
    print(io, uppercase(join(string(b, base = 16, pad = 2) for b in color)))
  end
  waveform = waveform_packet(pt)
  if !ismissing(waveform)
    print(io, ", waveform packet = ", waveform)
  end

  iszero(user_data(pt)) || print(io, ", user data = ", user_data(pt))
  print(io, ", source ID = ", source_id(pt))
  if !iszero(N)
    bytes = map(b -> string(b, base = 16, pad = 2), extra_bytes(pt))
    print(io, ", extra bytes = 0x", join(bytes))
  end
  print(io, ")")
end

pdrf_number(::Type{<:PointRecord{F}}) where F = F
pdrf_nonstandard_bytes(::Type{<:PointRecord{F,N}}) where {F,N} = N

function pdrf_description(::Type{UnknownPointRecord{F,N}}) where {F,N}
  "unsupported $N-byte PDRF $F"
end
function pdrf_description(::Type{<:PointRecord{F,N}}) where {F,N}
  string("PDRF ", F, iszero(N) ? "" : " with $N extra bytes")
end

function Base.read(io::Base.IO, ::Type{UnknownPointRecord{F,N}}) where {F,N}
  UnknownPointRecord{F,N}(ntuple(_ -> read(io, UInt8), N))
end

read_core_legacy(io) = (
  ntuple(_ -> read(io, Int32), 3),
  read(io, UInt16),
  ntuple(_ -> read(io, UInt8), 2),
  read(io, Int8),
  read(io, UInt8),
  read(io, UInt16),
)

read_core(io) = (
  ntuple(_ -> read(io, Int32), 3),
  read(io, UInt16),
  ntuple(_ -> read(io, UInt8), 3),
  read(io, UInt8),
  read(io, Int16),
  read(io, UInt16),
  read(io, Float64),
)

read_waveform(io) = (
  read(io, UInt8),
  read(io, UInt64),
  read(io, UInt32),
  read(io, Float32),
  ntuple(_ -> read(io, Float32), 3),
)

function Base.read(io::Base.IO, ::Type{PointRecord0{N}}) where {N}
  PointRecord0{N}(
    read_core_legacy(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord1{N}}) where {N}
  PointRecord1{N}(
    read_core_legacy(io)...,
    read(io, Float64),
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord2{N}}) where {N}
  PointRecord2{N}(
    read_core_legacy(io)...,
    ntuple(_ -> read(io, UInt16), 3),
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord3{N}}) where {N}
  PointRecord3{N}(
    read_core_legacy(io)...,
    read(io, Float64),
    ntuple(_ -> read(io, UInt16), 3),
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord4{N}}) where {N}
  PointRecord4{N}(
    read_core_legacy(io)...,
    read(io, Float64),
    read_waveform(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord5{N}}) where {N}
  PointRecord5{N}(
    read_core_legacy(io)...,
    read(io, Float64),
    ntuple(_ -> read(io, UInt16), 3),
    read_waveform(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord6{N}}) where {N}
  PointRecord6{N}(
    read_core(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord7{N}}) where {N}
  PointRecord7{N}(
    read_core(io)...,
    ntuple(_ -> read(io, UInt16), 3),
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord8{N}}) where {N}
  PointRecord8{N}(
    read_core(io)...,
    ntuple(_ -> read(io, UInt16), 4),
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord9{N}}) where {N}
  PointRecord9{N}(
    read_core(io)...,
    read_waveform(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.read(io::Base.IO, ::Type{PointRecord10{N}}) where {N}
  PointRecord10{N}(
    read_core(io)...,
    ntuple(_ -> read(io, UInt16), 4),
    read_waveform(io)...,
    ntuple(_ -> read(io, UInt8), N),
  )
end

function Base.write(io::Base.IO, pt::T) where {T<:PointRecord}
  for fname in fieldnames(T)
    data = getfield(pt, fname)
    if data isa Tuple
      foreach(val -> write(io, val), data)
    else
      write(io, data)
    end
  end
end

function point_record_type(pdrf, bytes)
  if pdrf in 0:10
    T = (PointRecord0, PointRecord1, PointRecord2, PointRecord3, PointRecord4, PointRecord5, PointRecord6, PointRecord7, PointRecord8, PointRecord9, PointRecord10)[pdrf + 1]
    nextra = bytes - sum(sizeof(t) for t in fieldtypes(T{0}))
    nextra >= 0 || error("Record length $bytes is too small for point format $pdrf")
    T{Int(nextra)}
  else
    @error "Unknown Point Data Record Format: $pdrf"
    UnknownPointRecord{Int(pdrf),Int(bytes)}
  end
end

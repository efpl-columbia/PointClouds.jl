abstract type PointRecord{F,N} end

struct UnknownPointRecord{F,N} <: PointRecord{F,N}
  data::NTuple{N,UInt8}
end

struct PointRecord0{N} <: PointRecord{0,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  category::NTuple{2,UInt8}
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
  category::NTuple{2,UInt8}
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
  category::NTuple{2,UInt8}
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
  category::NTuple{2,UInt8}
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
  category::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 4: gps time & waveform packets
  gps_time::Float64
  waveform_descriptor::UInt8
  waveform_offset::UInt64
  waveform_length::UInt32
  waveform_location::Float32
  waveform_direction::NTuple{3,Float32}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord5{N} <: PointRecord{5,N}
  # core items (legacy formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  category::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # format 5: gps time, rgb color & waveform packets
  gps_time::Float64
  color_channels::NTuple{3,UInt16}
  waveform_descriptor::UInt8
  waveform_offset::UInt64
  waveform_length::UInt32
  waveform_location::Float32
  waveform_direction::NTuple{3,Float32}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord6{N} <: PointRecord{6,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  category::NTuple{3,UInt8}
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
  category::NTuple{3,UInt8}
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
  category::NTuple{3,UInt8}
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
  category::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 9: waveform packets
  waveform_descriptor::UInt8
  waveform_offset::UInt64
  waveform_length::UInt32
  waveform_location::Float32
  waveform_direction::NTuple{3,Float32}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
end

struct PointRecord10{N} <: PointRecord{10,N}
  # core items (new formats)
  coords::NTuple{3,Int32}
  intensity::UInt16
  category::NTuple{3,UInt8}
  user_data::UInt8
  scan_angle::Int16
  source_id::UInt16
  gps_time::Float64
  # format 10: rgb + nir color & waveform packets
  color_channels::NTuple{4,UInt16}
  waveform_descriptor::UInt8
  waveform_offset::UInt64
  waveform_length::UInt32
  waveform_location::Float32
  waveform_direction::NTuple{3,Float32}
  # optional extra data
  extra_bytes::NTuple{N,UInt8}
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

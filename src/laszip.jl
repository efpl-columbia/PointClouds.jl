using LASzip_jll: LASzip_jll
const laszip = LASzip_jll.liblaszip

function laszip_version()
  major = Ref{Cuchar}()
  minor = Ref{Cuchar}()
  revision = Ref{Cushort}()
  build = Ref{Cuint}()
  rval = ccall(
    (:laszip_get_version, laszip),
    Cint,
    (Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt16}, Ptr{UInt32}),
    major,
    minor,
    revision,
    build,
  )
  iszero(rval) || error("Could not determine LASzip version ($rval)")
  VersionNumber(major[], minor[], revision[], (build[],))
end

struct LASzipPoint
  # core (legacy version)
  coords::NTuple{3,Int32}
  intensity::UInt16
  attributes::NTuple{2,UInt8}
  scan_angle::Int8
  user_data::UInt8
  source_id::UInt16
  # core fields introduced in v1.4
  extended_scan_angle::Int16
  extended_attributes::NTuple{3,UInt8}
  # for 8 byte alignment of the GPS time
  dummy::NTuple{7,UInt8}
  # optional fields of different formats
  gps_time::Float64
  color_channels::NTuple{4,UInt16}
  waveform_packet::NTuple{29,UInt8}
  extra_bytes_count::Int32
  extra_bytes::Ptr{UInt8}
end

integer_coordinates(pt::LASzipPoint) = pt.coords
intensity(::Type{UInt16}, pt::LASzipPoint) = pt.intensity
encoded_attributes(::Type{NTuple{2,UInt8}}, pt::LASzipPoint) = pt.attributes
function encoded_attributes(::Type{NTuple{3,UInt8}}, pt::LASzipPoint)
  a1, a2, a3 = pt.extended_attributes
  # LASzip reorders the bits of the point attribute data
  point_type = a1 & 0b00000011
  point_type == 1 || @error "LASzip point type not set to extended"
  scanner_channel = a1 & 0b00001100
  classification = a1 & 0b11110000
  direction = pt.attributes[1] & 0b01000000
  edge = pt.attributes[1] & 0b10000000
  # LAS order: classification, channel, scan direction, edge of flight line
  (a3, classification >> 4 | scanner_channel << 2 | direction | edge, a2)
end

integer_scan_angle(::Type{Int8}, pt::LASzipPoint) = pt.scan_angle
integer_scan_angle(::Type{Int16}, pt::LASzipPoint) = pt.extended_scan_angle
user_data(pt::LASzipPoint) = pt.user_data
source_id(pt::LASzipPoint) = pt.source_id
gps_time(pt::LASzipPoint) = pt.gps_time
function waveform_packet(pt::LASzipPoint)
  w1 = pt[1]
  w2 = reinterpret(UInt64, pt[2:9])
  w3 = reinterpret(UInt32, pt[10:13])
  w4 = reinterpret(Float32, pt[14:17])
  w5 = reinterpret(Float32, pt[18:21])
  w6 = reinterpret(Float32, pt[22:25])
  w7 = reinterpret(Float32, pt[26:29])
  (w1, w2, w3, w4, w5, w6, w7)
end
color_channels(::Type{NTuple{N,UInt16}}, pt::LASzipPoint) where {N} = pt.color_channels[1:N]
function extra_bytes(::Type{NTuple{N,UInt8}}, pt::LASzipPoint) where {N}
  @assert N isa Int # do not use non-standard integers as type parameter
  @assert pt.extra_bytes_count == N
  eb = reinterpret(Ptr{NTuple{N,UInt8}}, pt.extra_bytes)
  unsafe_load(eb)
end

struct LASzipReader{T} <: AbstractVector{T}
  file::String
  reader::Base.RefValue{Ptr{Cvoid}}
  current_point::Vector{LASzipPoint}
  current_index::Base.RefValue{Int}
  count::Int
end

function LASzipReader(filename, ::Type{T}, count) where {T}
  reader = Ref{Ptr{Cvoid}}()
  rval = ccall((:laszip_create, laszip), Cint, (Ptr{Ptr{Cvoid}},), reader)
  iszero(rval) || error("Could not create LASzip reader ($rval)")
  finalizer(r -> close_reader(r[], filename), reader)

  is_compressed = Ref{Cint}(0)
  rval = ccall(
    (:laszip_open_reader, laszip),
    Cint,
    (Ptr{Cvoid}, Ptr{UInt8}, Ptr{Cint}),
    reader[],
    filename,
    is_compressed,
  )
  iszero(rval) || error("Could not open LASzip reader for `$filename` ($rval)")
  iszero(is_compressed[]) &&
    @info "Using LASzip reader even though `$filename` is not compressed"

  point_ptr = Ref{Ptr{LASzipPoint}}()
  rval = ccall(
    (:laszip_get_point_pointer, laszip),
    Cint,
    (Ptr{Cvoid}, Ref{Ptr{LASzipPoint}}),
    reader[],
    point_ptr,
  )
  iszero(rval) || @error("Could not get LASzip point pointer ($rval)")
  current_point = unsafe_wrap(Array, point_ptr[], 1)

  LASzipReader{T}(filename, reader, current_point, Ref(0), count)
end

function close_reader(r::Ptr{Cvoid}, filename)
  if r == C_NULL
    @async @debug "LASzip reader for $filename is already closed"
    return
  end
  rval = ccall((:laszip_close_reader, laszip), Cint, (Ptr{Cvoid},), r)
  iszero(rval) || @async @error "Could not close LASzip reader for `$filename` ($rval)"
  rval = ccall((:laszip_destroy, laszip), Cint, (Ptr{Cvoid},), r)
  iszero(rval) || @async @error "Could not destroy LASzip reader for `$filename` ($rval)"
  @async @debug "Successfully closed LASzip reader for $filename"
end

function Base.close(laz::LASzipReader)
  close_reader(laz.reader[], laz.file)
  laz.reader[] = C_NULL
  laz
end

# iteration interface
Base.size(laz::LASzipReader) = (laz.count,)
function Base.iterate(laz::LASzipReader, ind::Integer = 1)
  ind > laz.count ? nothing : (laz[ind], ind + 1)
end
Base.isdone(laz::LASzipReader, ind::Integer = 1) = ind > laz.count

# read-only indexing interface
function Base.getindex(laz::LASzipReader, ind::Integer)
  if laz.current_index[] != ind - 1
    rval = ccall(
      (:laszip_seek_point, laszip),
      Cint,
      (Ptr{Cvoid}, Clonglong),
      laz.reader[],
      ind - 1,
    )
    iszero(rval) || @error("Could not seek LASzip point ($rval)")
    laz.current_index[] = ind - 1
  end
  rval = ccall((:laszip_read_point, laszip), Cint, (Ptr{Cvoid},), laz.reader[])
  iszero(rval) || @error("Could not read LASzip point ($rval)")
  laz.current_index[] += 1
  convert(eltype(laz), laz.current_point[])
end
Base.getindex(laz::LASzipReader, inds::BitVector) = MaskedPoints(laz, inds)
Base.getindex(laz::LASzipReader, inds::OrdinalRange) = IndexedPoints(laz, inds)

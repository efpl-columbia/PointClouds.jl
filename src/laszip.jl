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

readattr(P, ::Val{:coords}, pt::LASzipPoint) = pt.coords
readattr(P, ::Val{:intensity}, pt::LASzipPoint) = pt.intensity
function readattr(P, ::Val{:metadata}, pt::LASzipPoint)
  fieldtype(P, :metadata) <: NTuple{2} && return pt.attributes
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
function readattr(P, ::Val{:scan_angle}, pt::LASzipPoint)
  fieldtype(P, :scan_angle) <: Int8 ? pt.scan_angle : pt.extended_scan_angle
end
readattr(P, ::Val{:user_data}, pt::LASzipPoint) = pt.user_data
readattr(P, ::Val{:source_id}, pt::LASzipPoint) = pt.source_id
readattr(P, ::Val{:gps_time}, pt::LASzipPoint) = pt.gps_time
function readattr(P, ::Val{:waveform_packet}, pt::LASzipPoint)
  pkg = pt.waveform_packet
  w1 = pkg[1]
  w2 = reinterpret(UInt64, pkg[2:9])
  w3 = reinterpret(UInt32, pkg[10:13])
  w4 = reinterpret(Float32, pkg[14:17])
  w5 = reinterpret(Float32, pkg[18:21])
  w6 = reinterpret(Float32, pkg[22:25])
  w7 = reinterpret(Float32, pkg[26:29])
  (w1, w2, w3, w4, w5, w6, w7)
end
function readattr(P, ::Val{:color_channels}, pt::LASzipPoint)
  count(::Type{<:NTuple{N}}) where {N} = N
  pt.color_channels[1:count(fieldtype(P, :color_channels))]
end
function readattr(P, ::Val{:extra_bytes}, pt::LASzipPoint)
  N = fieldcount(fieldtype(P, :extra_bytes))
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
Base.getindex(laz::LASzipReader, inds::BitVector) = MaskedPoints(laz, inds)
Base.getindex(laz::LASzipReader, inds::OrdinalRange) = IndexedPoints(laz, inds)
function Base.getindex(laz::LASzipReader{P}, ind::Integer) where {P}
  P(getattrs(Val.(fieldnames(P)), laz, ind)...)
end

function getattrs(attrs::Tuple, pts::LASzipReader{P}, ind::Integer) where {P}
  @boundscheck checkbounds(pts, ind)
  laz_seek!(pts, ind)
  pt = laz_read!(pts)
  map(attr -> readattr(P, attr, pt), attrs)
end

function getattrs(attrs::Tuple, pts::LASzipReader{P}, inds::AbstractUnitRange) where {P}
  @boundscheck checkbounds(pts, inds)
  laz_seek!(pts, first(inds))
  # make sure to only call laz_read! once per point
  ((pt = laz_read!(pts); map(attr -> readattr(P, attr, pt), attrs)) for _ in inds)
end

function laz_seek!(laz::LASzipReader, ind::Integer)
  laz.current_index[] == ind - 1 && return
  rval = ccall(
    (:laszip_seek_point, laszip),
    Cint,
    (Ptr{Cvoid}, Clonglong),
    laz.reader[],
    ind - 1,
  )
  iszero(rval) || error("Could not seek LASzip point ($rval)")
  laz.current_index[] = ind - 1
end

function laz_read!(laz::LASzipReader)
  rval = ccall((:laszip_read_point, laszip), Cint, (Ptr{Cvoid},), laz.reader[])
  iszero(rval) || error("Could not read LASzip point ($rval)")
  laz.current_index[] += 1
  laz.current_point[]
end

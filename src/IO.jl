module IO

export LAS

import Dates

bytes_to_string(bytes) = String(bytes[1:something(findlast(!iszero, bytes), 0)])

function string_to_bytes(str, length)
  nb = ncodeunits(str)
  nb <= length || @error "String \"$str\" truncated to length $length"
  nb = min(nb, length)
  b = zeros(UInt8, length)
  b[1:nb] = codeunits(str)[1:nb]
  b
end

include("las-guid.jl")
include("las-vlrs.jl")
include("las-points.jl")

mutable struct LAS{T,P,V}

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
  creation_day::NTuple{2,UInt16}

  # encoding flags
  has_adjusted_standard_gps_time::Bool
  has_internal_waveform::Bool
  has_external_waveform::Bool
  has_synthetic_return_numbers::Bool
  has_well_known_text::Bool
end

Base.length(las::LAS{T,UInt64}) where {T} = las.points
Base.length(las::LAS{T,P}) where {T,P<:AbstractVector{T}} = length(las.points)

Base.eltype(las::LAS{T}) where {T} = T

Base.summary(las::LAS) = string(length(las), "-point LAS")

function Base.show(io::Base.IO, las::LAS{T}) where T
  print(io, summary(las), " (")
  print(io, "v$(las.version[1]).$(las.version[2])")
  print(io, ", ", pdrf_name(T), ", ")
  let (day, year) = las.creation_day
    if 1 <= day <= 366
      date = Dates.Date(year) + Dates.Day(day - 1)
      print(io, Dates.format(date, "dd u yyyy"))
    else
      print(io, "Day ", day, " Year ", year)
    end
  end
  print(io, ")")

  pad = 14
  print(io, rpad("\n  Source ID", pad), "=> ", iszero(las.source_id) ? "(unassigned)" : string(las.source_id))
  print(io, rpad("\n  Project ID", pad), "=> ")
  show(io, las.project_id)
  print(io, rpad("\n  System ID", pad), "=> \"", las.system_id, "\"")
  print(io, rpad("\n  Software ID", pad), "=> \"", las.software_id, "\"")

  nextra = length(las.extra_data)
  if !iszero(nextra)
    limit = nextra > 8 ? 6 : nextra
    print(io, rpad("\n  Extra Data", pad), "=> ")
    print(io, "[", join(("0x" * uppercase(string(b, base = 16, pad = 2)) for b in las.extra_data[1:limit]), ", "))
    nextra > limit && print(io, " … (", nextra - limit, " more bytes)")
    print(io, "]")
  end

  nvlr = length(las.vlrs)
  print(io, "\n  Variable-Length Records")
  map(las.vlrs[1:min(end, 5)]) do vlr
    print(io, "\n    => ")
    show(io, vlr)
  end
  nvlr > 5 && println("\n    => ($(nvlr - 5) more records)")
end

function read_las_signature(io)
  sig = ntuple(_ -> read(io, UInt8), 4)
  if sig != (UInt8('L'), UInt8('A'), UInt8('S'), UInt8('F'))
    error("Invalid file signature: $sig")
  end
end

function write_las_signature(io)
  write(io, UInt8('L'), UInt8('A'), UInt8('S'), UInt8('F'))
end

function Base.read(io::Base.IO, ::Type{LAS})
  read_las_signature(io)

  source_id = read(io, UInt16)

  # parse global encoding bit field
  encoding = read(io, UInt16)
  if !iszero(encoding >> 5)
    bits = string(encoding >> 5, base = 2, pad = 11)
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
  creation_day = ntuple(_ -> read(io, UInt16), 2)

  # parse various data-length fields
  header_size = read(io, UInt16)
  point_data_offset = read(io, UInt32)
  vlr_count = read(io, UInt32)
  pdrf_type = read(io, UInt8)
  pdrf_length = read(io, UInt16)
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
  for _ in 1:vlr_count
    iszero(remaining) && break
    vlr = read(io, VariableLengthRecord; version = version, max_bytes = remaining)
    isnothing(vlr) && break
    push!(vlrs, vlr)
    remaining -= 54 + length(vlr.data)
  end
  extra_data = read(io, remaining)

  # read point data, without choking on truncated files
  pdrf = point_record_format(pdrf_type, pdrf_length)
  points = Vector{pdrf}(undef, point_count_total)
  for ind in 1:point_count_total
    try
      points[ind] = read(io, pdrf)
    catch ex
      ex isa EOFError || rethrow()
      n = point_count_total - ind + 1
      s = n > 1 ? "s" : ""
      # TODO: check if discarded data can be added to error message
      @error "Point data ended prematurely ($n record$s missing)"
      resize!(points, ind - 1)
      break
    end
  end

  eof(io) || @error "Input longer than expected"

  LAS{pdrf, typeof(points), typeof(vlrs)}(
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
    creation_day,
    # encoding flags
    has_adjusted_standard_gps_time,
    has_internal_waveform,
    has_external_waveform,
    has_synthetic_return_numbers,
    has_well_known_text,
  )
end

function Base.write(io::Base.IO, las::LAS)
  major_version, minor_version = las.version
  major_version == 1 || error("Unsupported major LAS version v$major_version.$minor_version")
  minor_version <= 4 || error("Unsupported minor LAS version v$major_version.$minor_version")

  write_las_signature(io)
  write(io, las.source_id)
  encoding = UInt16(las.has_adjusted_standard_gps_time) |
    UInt16(las.has_internal_waveform) << 1 |
    UInt16(las.has_external_waveform) << 2 |
    UInt16(las.has_synthetic_return_numbers) << 3 |
    UInt16(las.has_well_known_text) << 4
  write(io, encoding)
  write(io, las.project_id)
  write(io, las.version...)
  write(io, string_to_bytes(las.system_id, 32))
  write(io, string_to_bytes(las.software_id, 32))
  write(io, las.creation_day...)
  header_size = (227, 227, 227, 235, 375)[minor_version + 1]
  write(io, UInt16(header_size))
  vlr_size = sum(54 + length(vlr.data) for vlr in las.vlrs; init = 0)
  write(io, UInt32(header_size + vlr_size + length(las.extra_data)))
  write(io, UInt32(length(las.vlrs)))
  println("header size = ", header_size, ", point-data offset = ", header_size + vlr_size + length(las.extra_data))

  pdrf = pdrf_id(eltype(las))
  write(io, UInt8(pdrf))
  write(io, UInt16(sum(sizeof(t) for t in fieldtypes(eltype(las)))))
    if (minor_version <= 1 && pdrf > 1) || (minor_version <= 2 && pdrf > 3) || (minor_version <= 3 && pdrf > 5)
    error("Point Data Record Format $pdrf is not allowed in LAS v1.$(minor_version)")
  end

  # legacy point count (total & by return)
  if minor_version < 4 && length(las) > typemax(UInt32)
    error("LAS v1.$(minor_version) does not support more than $(typemax(UInt32)) points")
  end
  if any(n > length(las) for n in las.return_counts)
    error("Points count by return type exceeds total point count")
  end
  if length(las) <= typemax(UInt32) && pdrf < 6
    write(io, UInt32(length(las)))
    foreach(i -> write(io, UInt32(las.return_counts[i])), 1:5)
  else
    foreach(_ -> write(io, zero(UInt32)), 1:6)
  end

  # coordinate-related fields
  write(io, las.coord_scale...)
  write(io, las.coord_offset...)
  write(io, las.coord_max[1])
  write(io, las.coord_min[1])
  write(io, las.coord_max[2])
  write(io, las.coord_min[2])
  write(io, las.coord_max[3])
  write(io, las.coord_min[3])

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
    foreach(i -> write(io, las.return_counts[i]), 1:15)
  else
    iszero(las.return_counts[6:15]) || @error "Non-zero point count for returns 6–15"
  end

  # write extra data, VLRs & points
  foreach(vlr -> write(io, vlr; minor_version = minor_version), las.vlrs)
  write(io, las.extra_data)
  foreach(pt -> write(io, pt), las.points)
end

end # module IO

struct VariableLengthRecord
  user_id::String
  record_id::UInt16
  data::Vector{UInt8}
  description::String
end

function Base.show(io::Base.IO, vlr::VariableLengthRecord)
  print(io, vlr.user_id, "[", vlr.record_id, "]")
  if !isempty(vlr.description)
    print(io, " \"", vlr.description, "\"")
  end
  print(io, " (", length(vlr.data), " bytes)")
end

function Base.read(
  io::Base.IO,
  ::Type{VariableLengthRecord};
  max_bytes = nothing,
  version = nothing,
)

  # check whether there are enough bytes left to read the record header
  if !isnothing(max_bytes) && max_bytes < 54
    return # data will end up in user-defined bytes
  end

  # read header fields
  reserved = read(io, UInt16)
  user_id = bytes_to_string(read!(io, Vector{UInt8}(undef, 16)))
  record_id = read(io, UInt16)
  record_length = read(io, UInt16)
  description = bytes_to_string(read!(io, Vector{UInt8}(undef, 32)))

  # check whether there are enough bytes left to read the record data
  if !isnothing(max_bytes) && max_bytes < 54 + record_length
    @error "Invalid variable-length records"
    record_length = max_bytes - 54
    # still build the truncated record to be conservative
  end

  # check value of reserved field
  if isnothing(version)
    # skip checks
  elseif version >= (1, 4)
    if !iszero(reserved)
      rstr = uppercase(string(reserved; base = 16, pad = 4))
      @warn "Reserved field in VLR header has non-zero value 0x$rstr"
    end
  elseif version == (1, 0)
    if reserved != 0xAABB
      rstr = uppercase(string(reserved; base = 16, pad = 4))
      @warn "Reserved field in VLR header has non-standard value 0x$rstr"
    end
  elseif !(iszero(reserved) || reserved == 0xAABB)
    # standards 1.1–1.3 do not specify the reserved field, but having a
    # value other than those two is unexpected enough to warrant a warning
    rstr = uppercase(string(reserved; base = 16, pad = 4))
    @warn "Reserved field in VLR header has non-standard value 0x$rstr"
  end

  data = read(io, record_length)
  VariableLengthRecord(user_id, record_id, data, description)
end

function Base.write(io::Base.IO, vlr::VariableLengthRecord; minor_version = 4)
  write(io, minor_version > 0 ? 0x0000 : 0xAABB)
  write(io, string_to_bytes(vlr.user_id, 16))
  write(io, vlr.record_id)
  write(io, UInt16(length(vlr.data)))
  write(io, string_to_bytes(vlr.description, 32))
  write(io, vlr.data)
end

# list of user IDs: https://www.asprs.org/misc/las-key-list.html
function get_vlr(vlrs, user_id, record_id)
  matches = filter(vlrs) do vlr
    vlr.user_id == user_id && vlr.record_id == record_id
  end
  isempty(matches) && return nothing
  length(matches) > 1 && @warn "VLR \"$user_id[$record_id]\" is not unique, using last one"
  matches[end]
end

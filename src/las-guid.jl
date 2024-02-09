struct GUID
  p1::UInt32
  p2::UInt16
  p3::UInt16
  p4::NTuple{8,UInt8}
end

function Base.string(guid::GUID)
  # see https://github.com/ASPRSorg/LAS/wiki/LAS-ProjectID-Encoding-and-Representation
  p1 = string(guid.p1, base = 16, pad = 8)
  p2 = string(guid.p2, base = 16, pad = 4)
  p3 = string(guid.p3, base = 16, pad = 4)
  p4 = prod(string(b, base = 16, pad = 2) for b in guid.p4[1:2])
  p5 = prod(string(b, base = 16, pad = 2) for b in guid.p4[3:end])
  uppercase(join((p1, p2, p3, p4, p5), '-'))
end

function Base.show(io::Base.IO, guid::GUID)
  # check if the last bytes can be interpreted as ascii
  id = string(guid)
  desc = bytes_to_string(collect(guid.p4))
  print(io, (!isempty(desc) && isascii(desc)) ? "$id \"$desc\"" : id)
end

function Base.read(io::Base.IO, ::Type{GUID})
  p1 = read(io, UInt32)
  p2 = read(io, UInt16)
  p3 = read(io, UInt16)
  p4 = ntuple(_ -> read(io, UInt8), 8)
  GUID(p1, p2, p3, p4)
end

function Base.write(io::Base.IO, guid::GUID)
  write(io, guid.p1, guid.p2, guid.p3, guid.p4...)
end

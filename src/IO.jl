module IO

export LAS

mutable struct LAS end

function read_las_signature(io)
  sig = ntuple(_ -> read(io, UInt8), 4)
  if sig != (UInt8('L'), UInt8('A'), UInt8('S'), UInt8('F'))
    error("Invalid file signature: $sig")
  end
end

function Base.read(io::Base.IO, ::Type{LAS})
  read_las_signature(io)
  LAS()
end

end

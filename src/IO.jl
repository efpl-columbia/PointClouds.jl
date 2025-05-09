module IO

export LAS, update, update!, PointRecord

# accessors for point fields
export classification,
  color_channels,
  extra_bytes,
  gps_time,
  intensity,
  is_edge_of_line,
  is_key_point,
  is_left_to_right,
  is_overlap,
  is_right_to_left,
  is_synthetic,
  is_withheld,
  return_count,
  return_number,
  scan_angle,
  scanner_channel,
  source_id,
  user_data,
  waveform_packet

using Dates: Dates
using Mmap: Mmap
using HTTP: HTTP
using Proj: Proj
import ..AbstractPointCloud
import ..getcrs
import ..coordinates

include("laszip.jl")
include("geokeys.jl")
include("las-util.jl")
include("las-vlrs.jl")
include("las-points.jl")
include("las-main.jl")

end # module IO

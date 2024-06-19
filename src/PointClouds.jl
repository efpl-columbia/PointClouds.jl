module PointClouds

export LAS, getcrs, update, update!

# accessors for point attributes
export classification,
  color_channels,
  coordinates,
  encoded_attributes,
  extra_bytes,
  gps_time,
  integer_coordinates,
  integer_scan_angle,
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

# definitions also used in other modules
abstract type AbstractPointCloud end
function getcrs end
function coordinates end

include("IO.jl")

using .IO

end # module PointClouds

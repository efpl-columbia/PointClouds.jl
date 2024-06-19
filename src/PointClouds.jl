module PointClouds

export PointCloud, LAS, getcrs, update, update!, PointRecord, rasterize, neighbors, neighbors!, apply, transform

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

# functions for accessing data sources
export gettiles, ScienceBase

# definitions also used in other modules
abstract type AbstractPointCloud end
function getcrs end
function coordinates end

include("IO.jl")
include("DataSources.jl")

using NearestNeighbors: NearestNeighbors
using Polyester: Polyester
using DataFrames: DataFrames
using Proj: Proj
using .IO, .DataSources

include("basics.jl")
include("rasterization.jl")
include("filtering.jl")
include("attributes.jl")

using .Attributes

end # module PointClouds

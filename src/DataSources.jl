module DataSources

export gettiles, ScienceBase

using Dates: Dates
using BaseDirs: BaseDirs
using HTTP: HTTP
using JSON3: JSON3
using ..IO: IO
import ..AbstractPointCloud

abstract type DataSource end
abstract type LocalPath <: DataSource end
const SOURCES = Type{<:DataSource}[]

struct PointCloudTile{S,D} <: AbstractPointCloud
  data::D
end

PointCloudTile(src::Type{S}, data::D) where {S,D} = PointCloudTile{S,D}(data)

"""
    gettiles([src::DataSource]; lat, lon, limit = 100)

Query the available data sources or a specific source `src` for tiles of
point-cloud data. This returns an array of `PointCloudTile`s, which only
contain the database entries. These value can be passed to the `LAS`
constructor to download and load the point data itself. They can also be passed
to `minimum`/`maximum`/`extent` to get the coordinate range covered by each
tile.

The `lat` and `lon` keyword arguments specify the latitude and longitude values
for the spatial query, specified in the [WGS
84](https://en.wikipedia.org/wiki/World_Geodetic_System) coordinate reference
system, which is also used by GPS and many online maps. The query will search
for tiles at a point, within a box, or within a polygon, depending on whether
one, two, or multiple coordinate values are provided.

The `limit` argument specifies the maximum number of tiles that are requested
from each data source. The APIs that are queried may have their own limits that
cannot be exceeded (1000 for ScienceBase). Beyond those paging is required
(i.e. requesting more results with an offset), which is not currently supported
by `gettiles`.
"""
gettiles(src; kws...) = error("No search function found for `$src`")

# function should be extended for individual data sources
gettiles(src, loc::Tuple{Real,Real}) = gettiles(src; lat = loc[1], lon = loc[2])
gettiles(loc::Tuple{Real,Real}) = gettiles(loc...)
function gettiles(lat::Real, lon::Real)
  tiles = PointCloudTile[]
  append!(tiles, gettiles.(SOURCES; lat = lat, lon = lon)...)
  tiles
end

function gettiles(path::AbstractString)
  isdir(path) || error("`$path` is not a directory")
  map(readdir(path)) do file
    PointCloudTile(LocalPath, (path = joinpath(path, file),))
  end
end

filename(tile::PointCloudTile{LocalPath}) = basename(tile.data.path)
tiledir(tile::PointCloudTile{LocalPath}) = dirname(tile.data.path)

function tiledir(src::Type{<:DataSource})
  proj = BaseDirs.Project("PointClouds")
  BaseDirs.User.cache(proj, string(nameof(src)))
end

function uri(t::PointCloudTile{S}) where {S}
  error("Tile `$(id(t))` from `$S` does not specify URI for download")
end
function filename(::PointCloudTile{S}) where {S}
  error("Tile source `$S` does not specify file name")
end
tiledir(::PointCloudTile{S}) where {S} = tiledir(S)

"""
Get the path to the LAS of a tile, downloading the file first if necessary.
"""
function fetchtile(tile::PointCloudTile)
  dir = tiledir(tile)
  path = joinpath(dir, filename(tile))
  if !isfile(path)
    @info "Tile `$path` not cached, downloading…"
    mkpath(dir)
    HTTP.download(uri(tile), path)
  end
  path
end

"""
    LAS(t::PointCloudTile; kws...)

Load the point-cloud data of a `PointCloudTile`, downloading the file if
necessary. Downloaded files are saved to the user’s cache directory as provided
by [BaseDirs.jl](https://github.com/tecosaur/BaseDirs.jl) and loaded from there
in the future.
"""
IO.LAS(tile::PointCloudTile; kws...) = IO.LAS(fetchtile(tile); kws...)

include("sciencebase.jl")

end # module DataSources

"""
    ScienceBase <: DataSource

[Lidar Point Cloud
(LPC)](https://www.sciencebase.gov/catalog/item/4f70ab64e4b058caae3f8def)
dataset in the [ScienceBase catalog](https://www.sciencebase.gov/catalog/) of
the [United States Geological Survey (USGS)](https://www.usgs.gov/).
This dataset contains raw point-cloud data produced as part of the [USGS 3D
Elevation Program (3DEP)](https://www.usgs.gov/3d-elevation-program), which is
approaching nationwide coverage of the United States.

According to the [USGS website](https://www.usgs.gov/3d-elevation-program), “all 3DEP products are available free of charge and without use restrictions” (see also: [Terms of Use for The National Map](https://www.usgs.gov/faqs/what-are-terms-uselicensing-map-services-and-data-national-map)). Note however that the [ScienceBase User Agreement](https://www.sciencebase.gov/catalog/UserAgreement/show) asks API users “to adhere to practices of responsible use in accordance to web convention”.

Pass this type to the [`gettiles`](@ref) function to query the `ScienceBase`
dataset. As per [the query
instructions](https://www.usgs.gov/sciencebase-instructions-and-documentation/building-search-queries),
each query can return a maximum of 1000 items. You can also obtain the
`PointCloudTile` of a specific ScienceBase item with `ScienceBase(id)`, where
the `id` can be obtained e.g. from the ScienceBase URL.
"""
abstract type ScienceBase <: DataSource end
push!(SOURCES, ScienceBase)

ScienceBase(id::AbstractString) = PointCloudTile(ScienceBase, (id = id,))

Base.summary(tile::PointCloudTile{ScienceBase}) = string("ScienceBase(", tile.data.id, ")")

function Base.show(io::Base.IO, tile::PointCloudTile{ScienceBase})
  print(io, "ScienceBase(", tile.data.id, ")")
  haskey(tile.data, :name) && print(io, ": ", tile.data.name)
end

function Base.minimum(tile::PointCloudTile{ScienceBase})
  ((tile.data.bbox.lat_min, tile.data.bbox.lon_min))
end
function Base.maximum(tile::PointCloudTile{ScienceBase})
  ((tile.data.bbox.lat_max, tile.data.bbox.lon_max))
end
Base.extrema(tile::PointCloudTile{ScienceBase}) = (minimum(tile), maximum(tile))

filename(tile::PointCloudTile{ScienceBase}) = string(tile.data.id, ".laz")
uri(tile::PointCloudTile{ScienceBase}) =
  if haskey(tile.data, :uri)
    tile.data.uri
  else
    sciencebase_lookup(tile.data.id).data.uri
  end

function gettiles(::Type{ScienceBase}; kws...)
  if isempty(kws)
    # return the 10 latest tiles
    sciencebase_query(; sort = "lastUpdated", order = "desc", limit = 10)
  elseif haskey(kws, :extent)
    sciencebase_query(; filter = string("extentQuery=", kws[:extent]))
  elseif haskey(kws, :lat) && haskey(kws, :lon)
    xs, ys = kws[:lon], kws[:lat]
    npt = length(xs)
    length(ys) == npt || error("Number of latitude and longitude values must be equal")
    limit = get(kws, :limit, 100)
    if npt == 1 # single point
      q = string("POINT(", xs[1], " ", ys[1], ")")
      sciencebase_query(; filter = string("spatialQuery=", q), limit = limit)
    elseif npt == 2 # bounding box
      x0, x1 = xs
      y0, y1 = ys
      bbox = wkt_polygon(((x0, y0), (x1, y0), (x1, y1), (x0, y1)))
      sciencebase_query(; filter = string("spatialQuery=", bbox), limit = limit)
    else # polygon
      q = wkt_polygon(zip(xs, ys))
      sciencebase_query(; filter = string("spatialQuery=", q), limit = limit)
    end
  else
    error("Could not determine ScienceBase query")
  end
end

function wkt_polygon(pts)
  coords = join((string(x, ' ', y) for (x, y) in pts), ',')
  origin = first(pts)
  if last(pts) != origin # close polygon
    coords *= string(',', origin[1], ' ', origin[2])
  end
  string("POLYGON((", coords, "))")
end

function sciencebase_lookup(id)
  query = (:format => "json", :fields => "id,title,webLinks,dates,spatial")
  resp = HTTP.get("https://www.sciencebase.gov/catalog/item/$id"; query = query)
  sciencebase_tile(JSON3.read(resp.body))
end

# see https://www.usgs.gov/sciencebase-instructions-and-documentation/building-search-queries
# and https://www.usgs.gov/sciencebase-instructions-and-documentation/item-core-model
function sciencebase_query(;
  limit::Integer = 100,
  order = "asc",
  sort = "dateCreated",
  extra_params...,
)
  query = (
    :format => "json",
    :fields => "id,title,webLinks,dates,spatial",
    :max => limit,
    :offset => 0,
    :filter => "parentId=4f70ab64e4b058caae3f8def", # 3DEP data collection
    #"filter" => "tags=Lidar Point Cloud (LPC)", # probably not needed
    :order => order, # asc or desc
    :sort => sort, # title, dateCreated, lastUpdated, or firstContact
    extra_params...,
  )
  resp = HTTP.get("https://www.sciencebase.gov/catalog/items"; query = query)
  sciencebase_tiles(JSON3.read(resp.body))
end

function sciencebase_tiles(resp)
  tiles = sciencebase_tile.(resp.items)
  if resp.total > length(tiles)
    @warn "Results are limited to $(length(tiles)) out of $(resp.total) matches"
  end
  tiles
end

function sciencebase_tile(item)
  uris = filter(item.webLinks) do l
    !l.hidden && l.type == "download" && l.title == "LAZ" && endswith(l.uri, "laz")
  end
  uri = if isempty(uris)
    @error "No download link found for “$(item.title)”"
    ""
  elseif length(uris) > 1
    @warn "Multiple download links found for “$(item.title)”"
    uris[1].uri
  else
    uris[].uri
  end
  bbox = item.spatial.boundingBox
  bbox =
    (lat_min = bbox.minY, lon_min = bbox.minX, lat_max = bbox.maxY, lon_max = bbox.maxX)
  function date(kind)
    Dates.Date(
      item.dates[findfirst(x -> x.type == kind, item.dates)].dateString,
      "yyyy-mm-dd",
    )
  end
  PointCloudTile(
    ScienceBase,
    (
      id = item.id,
      name = item.title,
      uri = uri,
      bbox = bbox,
      period = (date("Start"), date("End")),
    ),
  )
end

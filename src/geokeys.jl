# original standard: http://geotiff.maptools.org/spec/geotiffhome.html
# current standard: http://www.opengis.net/doc/IS/GeoTIFF/1.1

const GEOKEYS = [

  # GeoTIFF Configuration Keys

  (1024, UInt16, :GTModelType),
  (1025, UInt16, :GTRasterType),
  (1026, String, :GTCitation),

  # Geodetic CRS Parameter Keys

  (2048, UInt16, :GeodeticCRS),
  (2049, String, :GeodeticCitation),
  (2050, UInt16, :GeodeticDatum),
  (2051, UInt16, :PrimeMeridian),
  (2052, UInt16, :GeogLinearUnits),
  (2053, Float64, :GeogLinearUnitSize),
  (2054, UInt16, :GeogAngularUnits),
  (2055, Float64, :GeogAngularUnitSize),
  (2056, UInt16, :Ellipsoid),
  (2057, Float64, :EllipsoidSemiMajorAxis, :GeogLinearUnits),
  (2058, Float64, :EllipsoidSemiMinorAxis, :GeogLinearUnits),
  (2059, Float64, :EllipsoidInvFlattening),
  (2060, UInt16, :GeogAzimuthUnits),
  (2061, Float64, :PrimeMeridianLongitude, :GeogAngularUnits),

  # Projected CRS Parameter Keys

  (3072, UInt16, :ProjectedCRS),
  (3073, String, :ProjectedCitation),
  (3074, UInt16, :Projection),
  (3075, UInt16, :ProjMethod),
  (3076, UInt16, :ProjLinearUnits),
  (3077, Float64, :ProjLinearUnitSize),
  # Projection Parameters:
  (3078, Float64, :ProjStdParallel1, :GeogAngularUnits),
  (3079, Float64, :ProjStdParallel2, :GeogAngularUnits),
  (3080, Float64, :ProjNatOriginLong, :GeogAngularUnits),
  (3081, Float64, :ProjNatOriginLat, :GeogAngularUnits),
  (3082, Float64, :ProjFalseEasting, :ProjLinearUnits),
  (3083, Float64, :ProjFalseNorthing, :ProjLinearUnits),
  (3084, Float64, :ProjFalseOriginLong, :GeogAngularUnits),
  (3085, Float64, :ProjFalseOriginLat, :GeogAngularUnits),
  (3086, Float64, :ProjFalseOriginEasting, :ProjLinearUnits),
  (3087, Float64, :ProjFalseOriginNorthing, :ProjLinearUnits),
  (3088, Float64, :ProjCenterLong, :GeogAngularUnits),
  (3089, Float64, :ProjCenterLat, :GeogAngularUnits),
  (3090, Float64, :ProjCenterEasting, :ProjLinearUnits),
  (3091, Float64, :ProjCenterNorthing, :ProjLinearUnits),
  (3092, Float64, :ProjScaleAtNatOrigin),
  (3093, Float64, :ProjScaleAtCenter),
  (3094, Float64, :ProjAzimuthAngle, :GeogAzimuthUnits),
  (3095, Float64, :ProjStraightVertPoleLong, :GeogAzimuthUnits),

  # Vertical CRS Parameter Keys (4096-5119)

  (4096, UInt16, :Vertical),
  (4097, String, :VerticalCitation),
  (4098, UInt16, :VerticalDatum),
  (4099, UInt16, :VerticalUnits),
]

const GeoKeys = NamedTuple # could change this to a custom struct later

# read from missing params
read_param(::Nothing, _, _, _) = nothing

# read from bytes
function read_param(bytes::Vector{UInt8}, type, count, offset)
  read_param(IOBuffer(bytes), type, count, offset)
end

# read from IO
function read_param(io::Base.IO, ::Type{String}, count, offset)
  (seek(io, offset); String(read(io, count)))
end
function read_param(io::Base.IO, ::Type{T}, count, offset) where {T}
  count == 1 ? read(io, T) : read!(io, zeros(T, count))
end

# read from already parsed data
read_param(s::String, ::Type{String}, count, offset) = s[offset+1:offset+count]
function read_param(v::Vector{T}, ::Type{T}, count, offset) where {T}
  count == 1 ? v[offset+1] : v[offset+1:offset+count]
end

function read_geokey(directory::Base.IO; double_params = nothing, ascii_params = nothing)

  # read key entry bytes
  id = read(directory, UInt16)
  tiff_tag_location = read(directory, UInt16)
  count = read(directory, UInt16)
  offset = read(directory, UInt16)

  param = nothing

  if tiff_tag_location == 0
    param = offset
    count != 1 && @warn "Invalid count $count for GeoKey $id with TIFF tag location 0"
  end

  if tiff_tag_location == 34735
    # shorts can be stored at the end of the directory itself
    pos = position(directory)
    param = read_param(directory, UInt16, count, offset)
    seek(directory, pos)
  end

  if tiff_tag_location == 34736
    param = read_param(double_params, Float64, count, offset)
    isnothing(param) &&
      @error "GeoKey $id requires GeoDoubleParamsTag ($count values at offset $offset)"
  end

  if tiff_tag_location == 34737
    param = read_param(ascii_params, String, count, offset)
    if isnothing(param)
      @error "GeoKey $id requires GeoAsciiParamsTag ($count values at offset $offset)"
    else
      isascii(param) || @warn "GeoKey $id contains invalid ASCII characters"
      if param[end] == '|'
        param = param[1:end-1]
      else
        @warn "GeoKey $id is not terminated by a pipe character '|'"
      end
    end
  end

  tiff_tag_location in (0, 34735, 34736, 34737) ||
    @error "GeoKey $id requires TIFF tag $tiff_tag_location ($count values at offset $offset)"

  return id => param
end

struct EPSG
  id::UInt16
end

Base.show(io::Base.IO, x::EPSG) = print(io, "EPSG:", string(x.id))

function read_geokeys(directory::Base.IO; params...)

  # read header of directory
  directory_version = read(directory, UInt16)
  major_revision = read(directory, UInt16)
  minor_revision = read(directory, UInt16)
  key_count = read(directory, UInt16)

  # verify version numbers (print error but continue if not matching)
  directory_version != 1 &&
    @error "Unsupported GeoTIFF key directory version: $directory_version (must be 1)"
  major_revision != 1 ||
    (minor_revision != 0 && minor_revision != 1) &&
      @error "Unsupported GeoTIFF version: $key_revision.$minor_revision (must be 1.0 or 1.1)"

  geokeys = map(1:key_count) do _
    id, val = read_geokey(directory; params...)
    ind = findfirst(gk -> first(gk) == id, GEOKEYS)
    name = if isnothing(ind)
      q = val isa AbstractString ? "\"" : ""
      @warn "Unknown GeoKey with $id => $q$val$q"
      Symbol("GeoKey", id)
    else
      _, valtype, name = GEOKEYS[ind]
      @assert val isa valtype
      name
    end
    if val isa UInt16 && 1024 <= val <= 32766
      val = EPSG(val)
    end
    name => val
  end
  NamedTuple(geokeys)
end

function gk2wkt(gk)
  mt = gk.GTModelType
  if mt == 0
    error("Unknown GTModelType")
  elseif mt == 1 # 2d projected
    wkt_projected_cs(gk)
  elseif mt == 2 # geographic 2d
    wkt_geographic_cs(gk)
  elseif mt == 3 # cartesian 3d
    error("Not yet implemented")
  elseif mt == 32767
    error("User-Defined GTModelType")
  else
    error("Invalid GTModelType")
  end
end

function wkt_projected_cs(gk)
  k = gk.ProjectedCRS
  k isa EPSG && return epsgio(k)

  wkt_tag("PROJCS", get(gk, :ProjectedCitation, ""),
    wkt_geographic_cs(gk),
    wkt_projection(gk),
    wkt_parameters(gk), # {<parameter>,}*
    wkt_unit(gk, :ProjLinearUnits),
    # {<twin axes>,} {<authority>,}
  )
end

function wkt_projection(gk)
  k = gk.Projection
  k isa EPSG && return epsgio(k)

  # also see https://gdal.org/proj_list/
  methods = (
  ("Transverse_Mercator", 9807), # in WKT spec
  (:TransvMercator_Modified_Alaska__AlaskaConformal, nothing),
  (:ObliqueMercator__ObliqueMercator_Hotine, nothing),
  ("Laborde_Oblique_Mercator", 9813), # in WKT spec
  ("Swiss_Oblique_Cylindrical", 9814), # in WKT spec
  (:ObliqueMercator_Spherical, nothing),
  (:Mercator, nothing),
  ("Lambert_Conformal_Conic_2SP", 9802), # in WKT spec
  (:LambertConfConic_Helmert, nothing),
  ("Lambert_Azimuthal_Equal_Area", 9820),
  ("Albers_Conic_Equal_Area", 9822),
  ("Azimuthal_Equidistant", nothing),
  ("Equidistant_Conic", nothing),
  ("Stereographic", nothing),
  ("Polar_Stereographic", 9810), # in WKT spec, but could be 9829/9830 as well
  ("Oblique_Stereographic", 9809), # in WKT spec
  (:Equirectangular, nothing),
  ("Cassini_Soldner", 9806), # in WKT spec
  ("Gnomonic", nothing),
  ("Miller_Cylindrical", nothing),
  ("Orthographic", nothing),
  ("Polyconic", nothing),
  ("Robinson", nothing),
  ("Sinusoidal", nothing),
  ("VanDerGrinten", nothing),
  ("New_Zealand_Map_Grid", 9811), # in WKT spec
  ("Transverse_Mercator_South_Orientated", 9808), # in WKT spec
  )
  @assert length(methods) == 27

  method = gk.ProjMethod
  if 1 <= method <= 27
    name, id = methods[method]
    name isa String || error("Projection :name not yet implemented")
    wkt_tag("PROJECTION", name, (isnothing(id) ? () : (wkt_epsg(EPSG(id)),))...)
  else
    error("projection method $method not yet implemented")
  end
end

function wkt_parameters(gk)
  params = []
  add!(key) = haskey(gk, key) && error("Parameter not yet implemented: $key")
  add!(key, name) =
  haskey(gk, key) && push!(params, wkt_tag("PARAMETER", name, gk[key]))

  # add parameters with corresponding WKT name
  add!(:ProjStdParallel1, "standard_parallel_1") # WKT spec says standard_parallel1
  add!(:ProjStdParallel2, "standard_parallel_2") # WKT spec says standard_parallel2
  add!(:ProjNatOriginLong) # :GeogAngularUnits, alias ProjOriginLong
  add!(:ProjNatOriginLat, "latitude_of_origin") # in WKT spec, alias ProjOriginLat
  add!(:ProjFalseEasting, "false_easting") # in WKT spec
  add!(:ProjFalseNorthing, "false_northing") # in WKT spec
  add!(:ProjFalseOriginLong) # :GeogAngularUnits
  add!(:ProjFalseOriginLat) # :GeogAngularUnits
  add!(:ProjFalseOriginEasting) # :ProjLinearUnits
  add!(:ProjFalseOriginNorthing) # :ProjLinearUnits
  add!(:ProjCenterLong, "central_meridian") # in WKT spec
  add!(:ProjCenterLat) # :GeogAngularUnits
  add!(:ProjCenterEasting) # :ProjLinearUnits
  add!(:ProjCenterNorthing) # :ProjLinearUnits
  add!(:ProjScaleAtNatOrigin, "scale_factor") # in WKT spec, alias ProjScaleAtOrigin
  add!(:ProjScaleAtCenter) # no units
  add!(:ProjAzimuthAngle, "azimuth")
  add!(:ProjStraightVertPoleLong) # :GeogAzimuthUnits

  join(params, ',')
end

function wkt_geographic_cs(gk)
  k = gk.GeodeticCRS
  k isa EPSG && return epsgio(k)

  wkt_tag("GEOGCS", get(gk, :GeodeticCitation, ""),
    wkt_datum(gk),
    wkt_prime_meridian(gk),
    wkt_unit(gk, :GeogAngularUnits),
    # {,<twin_axes>} {,<authority>}
  )
end

function wkt_datum(gk)
  k = gk.GeodeticDatum
  k isa EPSG && return epsgio(k, "datum")

  wkt_tag("DATUM", "(User-Defined)",
    wkt_spheroid(gk),
    # {,<to wgs84>} {,<authority>}
  )
end

function wkt_prime_meridian(gk)
  k = gk.PrimeMeridian
  k isa EPSG && return epsgio(k, "primem")
  error("TODO: implement custom prime meridian")
  #<prime meridian> = PRIMEM["<name>", <longitude> {,<authority>}]
end

function wkt_spheroid(gk)
  k = gk.Ellipsoid
  k isa EPSG && return epsgio(k, "ellipsoid")
  error("TODO: implement custom ellipsoid")
  #<spheroid> = SPHEROID["<name>", <semi-major axis>, <inverse flattening> {,<authority>}]
end

function wkt_unit(gk, kind)
  k = gk[kind]
  if k == EPSG(9001)
    wkt_tag("UNIT", "metre", "1", wkt_epsg(k))
  elseif k == EPSG(9102)
    wkt_tag("UNIT", "degree", "0.0174532925199433",	wkt_epsg(k))
  else
    error("Unit not implemented: $k ($kind)")
  end
end

function epsgio(epsg, kind = nothing)
  url = string("https://epsg.io/", epsg.id, isnothing(kind) ? "" : "-$kind", ".wkt")
  String(HTTP.get(url).body)
end

wkt_quote(s) = '"' in s ? error("quote in wkt string") : string('"', s, '"')

wkt_epsg(e) = """AUTHORITY["EPSG","$(e.id)"]"""

function wkt_tag(tag, name, args...)
  """$tag["$name",$(join(args, ','))]"""
end

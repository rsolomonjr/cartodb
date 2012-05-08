--
-- Function to "safely" transform to webmercator
--
-- This function works around the existance of a valid range
-- for web mercator by "clipping" anything outside to the valid
-- range.
--
CREATE OR REPLACE FUNCTION CDB_TransformToWebmercator(geom geometry)
RETURNS geometry
AS
$$
DECLARE
  valid_extent GEOMETRY;
  latlon_input GEOMETRY;
  clipped_input GEOMETRY;
  to_webmercator GEOMETRY;
  ret GEOMETRY;
BEGIN

  -- This is the valid web mercator extent 
  --
  -- NOTE: some sources set the valid latitude range
  --       to -85.0511 to 85.0511 but as long as proj
  --       does not complain we are happy
  --
  valid_extent := ST_MakeEnvelope(-180, -89, 180, 89, 4326);

  -- Then we transform to WGS84 latlon, which is
  -- where we have known coordinates for the clipping
  -- 
  latlon_input := ST_Transform(geom, 4326);

  -- Don't bother clipping if the geometry boundary doesn't
  -- go outside the valid extent.
  IF latlon_input @ valid_extent THEN
    RETURN ST_Transform(latlon_input, 3857);
  END IF;

  -- Since we're going to use ST_Intersection on input
  -- we'd better ensure the input is valid
  -- TODO: only do this if the first ST_Intersection fails ?
  latlon_input := CASE
    -- See http://trac.osgeo.org/postgis/ticket/1719
    WHEN ST_Dimension(geom) = 0 OR
      GeometryType(geom) = 'GEOMETRYCOLLECTION' THEN latlon_input
      ELSE ST_CollectionExtract(
        ST_MakeValid(latlon_input),
        ST_Dimension(latlon_input)+1
        )
    END;

  -- Then we clip, trying to retain the input type
  -- 
  clipped_input := ST_Intersection(latlon_input, valid_extent);

  -- We transform to web mercator
  to_webmercator := ST_Transform(clipped_input, 3857);

  -- Finally we convert EMPTY to NULL 
  -- See https://github.com/Vizzuality/cartodb/issues/706
  -- And retain "multi" status
  ret := CASE WHEN ST_IsEmpty(to_webmercator) THEN NULL::geometry
      WHEN GeometryType(geom) LIKE 'MULTI%' THEN ST_Multi(to_webmercator)
      ELSE to_webmercator
  END;

  RETURN ret;
END
$$ LANGUAGE 'plpgsql' IMMUTABLE STRICT;

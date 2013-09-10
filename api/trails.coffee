crc32 = require('crc32')
_ = require('underscore')

trails_response = null
trails_etag = null

c_column_names = """
  name,
  long_name,
  image_url,
  roundtrip_m,
  elevation_gain_ft,
  elevation_highest_ft,
  latitude,
  longitude,
  trip_reports_count,
  description
"""

process_rows = (rows) ->
  _(rows).chain()
    .sortBy((row) -> -row.trip_reports_count)
    .map (row) ->
      [
        row.name,
        row.long_name,
        row.image_url,
        row.roundtrip_m,
        row.elevation_gain_ft,
        row.elevation_highest_ft,
        row.latitude,
        row.longitude,
        row.trip_reports_count,
      ]
    .value()


module.exports.search = (db, query, req, res) ->
  tokens = _(query.split(' ')).chain()
    .map((t) -> t.replace( /^\s+|\s+$/g, '').toLowerCase())
    .compact()
    .value()

  # TODO: Handle non-exact match search by matching tokens seperately
  db.all """
    SELECT #{c_column_names} FROM trails t
    JOIN reverse_index ri on ri.trail_name = t.name
    WHERE ri.token = ?
      AND longitude IS NOT NULL
      AND latitude IS NOT NULL
    ORDER BY trip_reports_count DESC
    LIMIT 500;
  """, tokens.join(' '), (err, rows) -> res.json process_rows(rows)


module.exports.index = (db, req, res) ->
  # Manually calculate ETag for extra efficiency
  if trails_etag
    res.set('ETag', trails_etag)
    if !req.stale
      res.send()
      return

  if trails_response
    res.send trails_response
    return

  trails = db.all """
      SELECT #{c_column_names} FROM trails
      WHERE longitude IS NOT NULL
        AND latitude IS NOT NULL
    """,
    (err, rows) ->
      trails_response = JSON.stringify(process_rows(rows))
      trails_etag = crc32(trails_response)
      res.set('ETag', trails_etag)
      res.send trails_response


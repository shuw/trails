crc32 = require('crc32')
_ = require('underscore')

trails_data = null
trails_data_etag = null

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
    .filter (row) ->
      row.latitude && row.longitude
    .sortBy (row) ->
      -row.trip_reports_count
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


module.exports.search = (db, terms, req, res) ->
  db.all """
    SELECT #{c_column_names} FROM trails t
    JOIN reverse_index ri on ri.trail_name = t.name
    WHERE ri.token = ?
    ORDER BY trip_reports_count DESC
    LIMIT 500;
  """, terms, (err, rows) -> res.json process_rows(rows)


module.exports.index = (db, req, res) ->
  # Manually calculate ETag for extra efficiency
  if trails_data_etag
    res.set('ETag', trails_data_etag)
    if !req.stale
      res.json {}
      return

  if trails_data
    res.json trails_data
    return

  trails = db.all "SELECT #{c_column_names} FROM trails",
    (err, rows) ->
      trails_data = process_rows(rows)
      trails_data_etag = crc32(JSON.stringify(trails_data))
      res.set('ETag', trails_data_etag)
      res.json trails_data


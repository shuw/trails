sqlite3 = require 'sqlite3'
crc32 = require('crc32')
_ = require('underscore')

db = new sqlite3.Database 'crawler/data/trails.db', sqlite3.OPEN_READONLY, ->
  console.log('Trails DB loaded')

trails_data = null
trails_data_etag = null

module.exports = (req, res) ->
  # Manually calculate ETag for extra efficiency
  if trails_data_etag
    res.set('ETag', trails_data_etag)
    if !req.stale
      res.json {}
      return

  if trails_data
    res.json trails_data
    return

  trails = db.all """
    SELECT
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
    FROM trails
    """,
    (err, rows) ->
      trails_data = _(rows).chain()
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

      trails_data_etag = crc32(JSON.stringify(trails_data))
      res.set('ETag', trails_data_etag)
      res.json trails_data


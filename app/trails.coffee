sqlite3 = require 'sqlite3'
crc32 = require('crc32')

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
    SELECT name, trip_reports_count, long_name, longitude, latitude
    FROM trails
    """,
    (err, rows) ->
      trails_data = rows
      trails_data_etag = crc32(rows)
      res.set('ETag', trails_data_etag)
      res.json trails_data


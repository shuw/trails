crc32 = require 'crc32'
_ = require 'underscore'
_.str = require 'underscore.string'

_.mixin _.str.exports()

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
    .first(10)
    .value()

  token_conditions = _(tokens).map (t, idx) -> 'token LIKE ?'

  query = """
    SELECT #{c_column_names}, score, match_tokens, match_scores
    FROM trails t
    JOIN (
      SELECT trail_name,
             GROUP_CONCAT(token) AS match_tokens,
             GROUP_CONCAT(score) AS match_scores,
             SUM(score) AS score
      FROM reverse_index
      WHERE #{token_conditions.join(" OR ")}
      GROUP BY trail_name
    ) AS ri
    ON ri.trail_name = t.name
    ORDER BY score DESC
    LIMIT 100
  """

  get_score = (row) ->
  db.all query, _(tokens).map((t) -> t + '%'), (err, rows) ->

    rows = _(rows).sortBy (row) ->
      match_tokens = row.match_tokens.split(',')
      match_scores = row.match_scores.split(',')

      row.score = 0
      for expected in tokens
        for idx in [0...match_tokens.length]
          match_token = match_tokens[idx]
          match_score = parseInt(match_scores[idx])
          if expected == match_token
            row.score += 10 * match_score
            break
          if _(match_token).startsWith(expected)
            row.score += 1 * match_score
            break

      row.score += row.trip_reports_count * 0.01
      -row.score

    if rows.length
      top_score = rows[0].score
      rows = _(rows).filter (row) -> row.score > top_score * 0.5

    res.json process_rows rows


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
    ORDER BY trip_reports_count DESC
  """,
  (err, rows) ->
    trails_response = JSON.stringify(process_rows(rows))
    trails_etag = crc32(trails_response)
    res.set('ETag', trails_etag)
    res.send trails_response


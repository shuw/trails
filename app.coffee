connect = require 'connect'
connect_assets = require 'connect-assets'
express = require 'express'
jade = require 'jade'
sqlite3 = require 'sqlite3'

app = express()

app.configure ->
  app.set 'view engine', 'jade'
  app.set 'views', __dirname + '/views'

  app.use connect_assets()
  app.use connect.bodyParser()
  app.use connect.static(__dirname + '/public')
  app.use app.router

app.configure 'development', ->
  app.use express.errorHandler
    dumpExceptions: true
    showStack     : true

app.configure 'production', ->
  app.use express.errorHandler()

app.get '/', (req, res) ->
  res.render 'map', {}

app.get '/api/trails', (req, res) ->
  trails = db.all """
    SELECT name, trip_reports_count, long_name, longitude, latitude
    FROM trails
    """,
    (err, rows) ->
      res.json rows

db = new sqlite3.Database 'crawler/data/trails.db', sqlite3.OPEN_READONLY, ->
  console.log('DB loaded')
  server = app.listen(process.env.PORT || 8090)
  console.log 'Server started on port %s', server.address().port

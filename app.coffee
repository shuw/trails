connect = require 'connect'
connect_assets = require 'connect-assets'
express = require 'express'
jade = require 'jade'
api_trails = require './api/trails.coffee'
sqlite3 = require 'sqlite3'
async = require 'async'
_ = require 'underscore'
_.str = require 'underscore.string'

_.mixin _.str.exports()

db = new sqlite3.Database 'db/trails.db', sqlite3.OPEN_READONLY, ->
  console.log('Trails DB loaded')

process.on 'uncaughtException', (err) ->
  console.error("Error: " + err)

module.exports = app = express()

app.configure ->
  app.set 'view engine', 'jade'
  app.set 'views', __dirname + '/views'

  app.use express.compress()
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

app.get '/t/:trail_name', (req, res) ->
  db.get "SELECT * FROM trails WHERE name = ?", req.params.trail_name, (err, trail) ->
    res.render 'map', _: _, trail: trail

app.get '/q/:search_query', (req, res) ->
  res.render 'map', {}

app.get '/trails/:trail_name', (req, res) ->
  async.parallel([
      (cb) -> db.get "SELECT * FROM trails WHERE name = ?", req.params.trail_name, cb,
      (cb) -> db.all "SELECT name FROM locations WHERE trail_name=?;", req.params.trail_name, cb
    ],
    (err, results) ->
      [trail, locations] = results
      locations = _(locations).chain()
        .map((t) -> _(t.name).trim())
        .filter((t) -> t.length > 0)
        .value()

      res.render 'trail',
        _: _
        trail: trail
        locations: locations
  )

app.get '/api/trails', (req, res) ->
  api_trails.index(db, req, res)

app.get '/api/search/:query', (req, res) ->
  api_trails.search(db, req.params.query, req, res)

server = app.listen(process.env.PORT || 8090)
console.log 'Server started on port %s', server.address().port


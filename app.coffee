connect = require 'connect'
connect_assets = require 'connect-assets'
express = require 'express'
jade = require 'jade'
api_trails = require './api/trails.coffee'
sqlite3 = require 'sqlite3'
async = require 'async'
_ = require 'underscore'
_s = require 'underscore.string'

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

app.get '/trails/:trail_name', (req, res) ->
  async.parallel([
      (cb) -> db.get "SELECT * FROM trails WHERE name = ?", req.params.trail_name, cb,
      (cb) -> db.all "SELECT token FROM reverse_index WHERE trail_name=?;", req.params.trail_name, cb
    ],
    (err, results) ->
      [trail, tokens] = results
      tokens = _(tokens).chain()
        .map((t) -> t.token)
        .filter((t) -> t.length < 30)
        .value()
  
      res.render 'trail',
        _s: _s
        trail: trail
        tokens: tokens
  )

app.get '/api/trails', (req, res) ->
  api_trails.index(db, req, res)

app.get '/api/search/:terms', (req, res) ->
  api_trails.search(db, req.params.terms, req, res)

server = app.listen(process.env.PORT || 8090)
console.log 'Server started on port %s', server.address().port


connect = require 'connect'
connect_assets = require 'connect-assets'
express = require 'express'
jade = require 'jade'
api_trails = require './api/trails.coffee'
sqlite3 = require 'sqlite3'
_s = require 'underscore.string'

process.on 'uncaughtException', (err) ->
  console.error(err)

module.exports = app = express()

db = new sqlite3.Database 'crawler/data/trails.db', sqlite3.OPEN_READONLY, ->
  console.log('Trails DB loaded')

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
  db.get "SELECT * FROM trails WHERE name = ?",
    req.params.trail_name,
    (err, trail) ->
      res.render 'trail',
        _s: _s
        trail: trail

app.get '/api/trails', (req, res) ->
  api_trails(db, req, res)

server = app.listen(process.env.PORT || 8090)
console.log 'Server started on port %s', server.address().port


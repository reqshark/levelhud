
fs      = require 'fs'
http    = require 'http'
stream  = require 'stream'
express = require 'express'
WServer = require('ws').Server

app = express()

# -----------------------------------------------------------------------------

app.configure ->
    app.set 'views', "#{__dirname}/views"
    app.set 'view engine', 'html'
    app.engine 'html', (file, options, callback) ->
        fs.readFile file, (err, file) -> callback err, file.toString()
    app.use app.router
    app.use express.static "#{__dirname}/public"
    app.use express.errorHandler dumpExceptions: true, showStack: true

app.get '/', (req, res) ->
    res.render 'index'

# -----------------------------------------------------------------------------

log = (args...) -> console.log '[LevelDB] ' + args.join(' ')

class GUI
    constructor: (db) ->
        @use db

    use: (db) =>
        @level = db
        return this

    WSSetup: (@ws) =>
        log "Client connected"
        @send = (message) => @ws.send JSON.stringify message
        ws.on 'message', @socketAPI

    socketAPI: (data) =>
        return unless try data = JSON.parse data
        { method, args } = data

        log "#{method} [#{args}]"

        if method is 'get'
            args.push (error, results) => @send { error, results }
            @level[method].apply @level, args

        if method is 'put'
            message = "It went okay"
            args.push (error, results) => @send { error, message, key: args[0], value: args[1] }
            @level[method].apply @level, args

        if method is 'del'
            message = "Key '#{args[0]}' removed."
            args.push (error, results) => @send { error, message }
            @level[method].apply @level, args

        if method in ['createReadStream', 'createKeyStream', 'createValueStream']
            options = args[0] || {}
            options.limit ?= 100
            s = @level[method](options)
            s.on 'data', (data) =>
                switch method
                    when 'createKeyStream'   then data = { key: data, value: '' }
                    when 'createValueStream' then data = { key: '', value: data }
                @send data
            s.on 'error', (error) => @send { error }

    listen: (port = 4420) =>
        server = http.createServer(app)
        server.listen port

        wss = new WServer { server }
        wss.on 'connection', @WSSetup

        log "Server listening on port #{port}"

module.exports = GUI

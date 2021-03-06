DockerCommander = require '../lib/controller'
utils = require '../middlewares/utils'

commander = new DockerCommander()

install = (name, app, cb) ->
    commander.exist name, (err, docExist) ->
        return cb err if err
        if not docExist
            if name in ['home', 'proxy', 'datasystem']
                app.password = utils.getToken()
            docker = app.repository.url.split('/')[3]
            if docker is "mycozycloud"
                docker = "cozy"
            commander.install "#{docker}/#{name}", 'latest', {}, (err) =>
                cb (err)
        else
            cb()

# post /drones/:slug/start
module.exports.start = (req, res, next) ->
    app = req.body.start
    name = app.name
    install name, app, (err) =>
        next err if err?
        switch name
            when 'data-system'
                commander.startDataSystem (err) ->
                    next err if err?
                    res.send 200, app
            when 'couchdb'
                commander.startCouch (err) ->
                    next err if err?
                    res.send 200, app
            when 'proxy'
                commander.startProxy (err, app) ->
                    next err if err?
                    res.send 200, app
            else
                env = "NAME=#{name} TOKEN=#{app.password}"
                docker = app.repository.url.split('/')[3]
                commander.startApplication "#{docker}/#{name}", env, (err, image, port) =>
                    next err if err?
                    app.port = port
                    res.send 200, drone: app

# post /drones/:slug/stop
module.exports.stop = (req, res, next) ->
    app = req.body.stop
    commander.exist app.name, (err, docExist) ->
        return cb err if err
        if docExist
            commander.stop app.name, (err, image) ->
                next err if err?
                res.send 200, {}
        else
            res.send 404, {}

# post /drones/:slug/light-update
module.exports.update = (req, res, next) ->
    app = req.body.update
    commander.exist app.name, (err, docExist) ->
        return cb err if err
        if docExist
            env = "NAME=#{app.name} TOKEN=#{app.password}"
            docker = app.repository.url.split('/')[3]
            commander.updateApplication "#{docker}/#{app.name}", env, (err, image, port) =>
                next err if err?
                app.port = port
                res.send 200, drone: app

# post /drones/:slug/clean
module.exports.clean = (req, res, next) ->
    app = req.body
    commander.exist app.name, (err, docExist) ->
        return cb err if err
        if docExist
            commander.uninstallApplication app.name, (err) ->
                next err if err?
                res.send 200, {}
        else
            res.send 404, {}

# get /drones/running
module.exports.running = (req, res, next) ->
    commander.running (err, result) ->
        return nex err if err
        res.send 200, result


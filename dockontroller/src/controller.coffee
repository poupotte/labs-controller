Docker = require 'dockerode'
logrotate = require 'logrotate-stream'
request = require 'request'

module.exports = class DockerCommander

    # docker connection options
    socketPath: process.env.DOCKERSOCK or '/var/run/docker.sock'
    version: 'v1.10'

    constructor: ->
        @docker = new Docker {@socketPath, @version}

    getContainerVisibleIp: ->
        addresses = require('os').networkInterfaces()['docker0']
        return ad.address for ad in addresses when ad.family is 'IPv4'


    # useful params
    # Volumes
    #
    install: (imagename, version, params, callback) ->
        console.log "INSTALLING", imagename

        options =
            fromImage: imagename,
            tag: version

        # pull the image
        @docker.createImage options, (err, data) =>
            return callback err if err

            slug = imagename.split('/')[-1..]
            options =
                'name': slug
                'Image': imagename
                'Tty': false

            options[key] = value for key, value of params

            # create a container
            @docker.createContainer options, callback


    uninstall: (slug, callback) ->

        @stop slug, (err, image) ->
            return callback err if err

            container.remove (err) ->

    # fire up an ambassador that allow container to speak to the host
    ambassador: (slug, port, callback) ->
        console.log "AMBASSADOR", slug, port

        ip = @getContainerVisibleIp()
        options =
            name: slug
            Image: 'aenario/ambassador'
            Env: "#{slug.toUpperCase()}_PORT_#{port}_TCP=tcp://#{ip}:#{port}"
            ExposedPorts: {}

        options.ExposedPorts["#{port}/tcp"] = {}

        @docker.createContainer options, (err) =>
            return callback err if err
            container = @docker.getContainer slug
            container.start {}, callback

    # useful params
    # Links
    #
    start: (slug, params, callback) ->
        console.log "STARTING", slug
        container = @docker.getContainer slug
        logfile = "/var/log/cozy_#{slug}.log"
        logStream = logrotate file: logfile, size: '100k', keep: 3

        # @TODO, do the piping in child process ?
        singlepipe = stream: true, stdout: true, stderr: true
        container.attach singlepipe, (err, stream) ->
            return callback err if err

            stream.setEncoding 'utf8'
            stream.pipe logStream, end: true

            startOptions = params

            container.start startOptions, (err) ->
                return callback err if err

                container.inspect (err, data) ->
                    return callback err if err

                    # we wait for the container to actually start (ie. listen)
                    pingHost = data.NetworkSettings.IPAddress
                    pingPort = key.split('/')[0] for key, val of data.NetworkSettings.Ports
                    pingUrl = "http://#{pingHost}:#{pingPort}/"

                    i = 0
                    do ping = ->
                        console.log "PING", pingUrl, i++
                        request.get pingUrl, (err, response, body) ->
                            if err
                                setTimeout ping, 500
                            else callback null, data


    stop: (slug, callback) ->
        container = @docker.getContainer slug
        container.inspect (err, data) ->
            return callback err if err
            image = data.Image

            unless data.State.Running
                return callback null, image

            container.stop (err) ->
                return callback err if err
                callback null, image


    startCouch: (callback) ->
        @start 'couchdb', {}, callback

    startDataSystem: (callback) ->
        @start 'datasystem', Links: ['couchdb:couch'], callback

    startHome: (callback) ->
        @start 'home',
            PublishAllPorts: true
            Links: ['datasystem:datasystem', 'proxy:proxy']
        , callback

    startApplication: (slug, callback) ->
        @start slug,
            PublishAllPorts: true
            Links: ['datasystem:datasystem']
        , callback
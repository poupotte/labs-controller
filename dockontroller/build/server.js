// Generated by CoffeeScript 1.7.1
var americano, initialize, port;

americano = require('americano');

initialize = require('./server/initialize');

port = process.env.PORT || 9002;

americano.start({
  name: 'cozy-controller',
  port: port
}, function(app, server) {
  return initialize(app, server, (function(_this) {
    return function() {
      return app.server = server;
    };
  })(this));
});
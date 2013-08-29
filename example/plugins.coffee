# Plugins for Primus, used on both sides of the connection

verbose =
  server: (primus) ->
    ['connection', 'disconnection', 'initialised'].forEach (type) ->
      primus.on type, (socket) ->
        console.info "primus (#{type})", new Date
  client: (primus) ->
    # only report the first error, but do it very disruptively!
    primus.once 'error', alert

tick =
  server: (primus) ->
    setInterval ->
      primus.write Date.now()
    , 1000
  client: (primus) ->
    primus.transform 'incoming', (packet) ->
      if typeof packet.data is 'number'
        console.log 'tick', packet.data

angular =
  client: (primus) ->
    # define an Angular module which injects incoming events The Angular Way
    # this module must be added as dependency in the main Angular application
    ng = angular.module 'primus', []
    ng.run [
      '$rootScope',
      ($rootScope) ->

        # TODO 'open' event fails regularly in 1.4.0, use private event for now
        primus.on 'incoming::open', (arg) ->
          $rootScope.$apply -> $rootScope.serverConnection = 'open'
        primus.on 'end', (arg) ->
          $rootScope.$apply -> $rootScope.serverConnection = 'closed'
        primus.on 'reconnect', (arg) ->
          $rootScope.$apply -> $rootScope.serverConnection = 'lost'

        primus.on 'data', (arg) ->
          $rootScope.$apply ->
            switch
              when arg.constructor is String
                $rootScope.serverMessage = arg
              when typeof arg is 'number'
                $rootScope.serverTick = arg
              when Array.isArray arg
                $rootScope.$broadcast arg...
              when arg instanceof Object
                $rootScope.$broadcast 'server', arg
    ]

module.exports = { verbose, tick, angular }
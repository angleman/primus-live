# Supervisor process, used to keep the HTTP + WebSocket running
# -jcw, 2013-09-01

cluster = require 'cluster'
preflight = require './preflight'

# Load via CoffeeScript, which is known to be installed as local dependency
cluster.setupMaster
  exec: __dirname + '/node_modules/.bin/coffee'
  args: [__dirname + '/worker.coffee']

cluster.on 'exit', (worker, code, signal) ->
  exitCode = worker.process.exitCode
  console.info 'worker', worker.process.pid, 'exit code', exitCode
  startWorker worker.process.exitCode and 5000 # wait 5s if exit was abnormal

startWorker = (delay) ->
  setTimeout ->
    worker = cluster.fork()
    console.info 'worker', worker.process.pid, 'started'
  , delay

preflight ->
  console.info '>>> starting live server'
  startWorker 0

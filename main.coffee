# Real-time server, using Primus to handle the WebSocket transport
# -jcw, 2013-08-26

http = require 'http'
path = require 'path'
fs = require 'fs'
jade = require 'jade'
stylus = require 'stylus'
coffee = require 'coffee-script'
marked = require 'marked'
connect = require 'connect'
Primus = require 'primus'

APP_DIR = './app'

serveCompiled = (root) ->
  (req, res, next) ->

    setResponse = (mime, data) ->
      bytes = Buffer.byteLength data
      res.writeHead 200, 'Content-Type': mime, 'Content-Length': bytes
      res.end data

    dest = root + req.uri.pathname
    dest += '/index.html'  if dest.substr(-1) is '/'
    src = data = undefined

    canCompile = (suffix, extensions...) ->
      if path.extname(dest) is suffix
        for ext in extensions
          src = dest.replace(suffix,'') + ext
          try
            return data = fs.readFileSync src, encoding: 'utf8'
      false

    switch
      when canCompile '.html', '.jade'
        setResponse 'text/html',
          do jade.compile data, filename: src
      when canCompile '.html', '.md'
        setResponse 'text/html',
          marked data
      when canCompile '.js', '.coffee'
        setResponse 'application/javascript',
          coffee.compile data
      when canCompile '.js', '.coffee.md', '.litcoffee'
        setResponse 'application/javascript',
          coffee.compile data, literate: true
      when canCompile '.css', '.styl'
        stylus.render data, filename: src, (err, css) ->
          throw err  if err
          setResponse 'text/css', css
      else
        next()

app = connect()
app.use connect.logger 'dev'
app.use connect.static APP_DIR
app.use connect.static './bower_components'
app.use serveCompiled APP_DIR
app.use connect.errorHandler()

watchDir = (path, cb) -> # recursive directory watcher
  fs.stat path, (err, stats) ->
    if not err and stats.isDirectory()
      fs.watch path, cb
      fs.readdir path, (err, files) ->
        unless err
          watchDir "#{path}/#{f}", cb  for f in files

try # silently ignore missing plugins
  plugins = require "#{process.cwd()}/plugins"
catch err
  throw err  unless err.code is 'MODULE_NOT_FOUND'

server = http.createServer app
primus = new Primus server, transformer: 'engine.io', plugin: plugins ? {}

primus.use 'live',
  server: (primus) ->
    watchDir APP_DIR, (event, path) ->
      reload = not /\.(css|styl)$/.test path
      console.info 'reload:', reload, '-', event, path
      primus.write reload  # broadcast true or false
      if /\.(js|coffee|coffee\.md|litcoffee)$/.test path
        console.info 'exit due to code change:', path
        process.exit 0
  client: (primus) ->
    primus.on 'data', (data) ->
      if data is true
        # TODO: delay hack is needed in case the server had to restart a worker
        setTimeout (-> window.location.reload true), 500
      else if data is false
        for e in document.getElementsByTagName 'link'
          if e.href and /stylesheet/i.test e.rel
            e.href = "#{e.href.replace /\?.*/, ''}?#{Date.now()}"

server.listen 8080
console.info 'server listening on :8080'

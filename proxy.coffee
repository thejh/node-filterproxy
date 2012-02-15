coffee = require 'coffee-script'

async = require 'async'
fs = require 'fs'
http = require 'http'
{createGunzip} = require 'zlib'
{checkURL} = require './urlcheck'
{InsertingStream} = require './streaminsert'

console.error = ->
logging = JSON.parse process.argv[2]

# Script injections (scripts to insert into server->client data)
injections = []

proxyUrlRegex = /^http:\/\/([^\/]*)\/(.*)$/

denyRequest = (response, reason, code = 403) ->
  response.writeHead code
  response.write reason, 'utf8'
  response.end()

# Prepare the proxy.
server_cb = (request, response) ->
  host = request.headers.host
  delete request.headers['accept-encoding']
  delete request.headers['proxy-connection']
  request.headers['accept-charset'] = 'utf-8'
  if 0 is request.url.indexOf 'http://'
    [_, host, request.url] = proxyUrlRegex.exec request.url
    request.url = '/' + request.url
  [host, port] = host.split ':'
  port = +port
  port = 80 if isNaN port
  fullurl = "#{host}#{[":#{port}" if port isnt 80]}#{request.url}"
  showurl = fullurl.slice(0, 100)
  
  {block, blockReason} = checkURL fullurl
  if block
    console.error "blocked request for '#{fullurl}', reason: #{blockReason}"
    console.log "✗ #{showurl}" if logging
    return denyRequest response, blockReason
  
  proxy_request = http.request
    method: request.method
    path: request.url
    headers: request.headers
    host: host
    port: port
  proxy_request.on 'error', (err) ->
    denyRequest response, err+'', 404
  proxy_request.addListener 'response', (proxy_response) ->
    writeToClient = (chunk) ->
      return response.end() if chunk is null
      response.write chunk
    console.error "request for '#{fullurl}'"
    #console.error "  HEADERS: #{JSON.stringify request.headers}"
    if proxy_response.headers["content-type"]?.indexOf("text/") is 0 or proxy_response.headers["content-type"]?.indexOf("javascript") isnt -1
      for injection in injections when ~fullurl.search injection.urlregex
        writeToClient = do (writeToClient) ->
          inserter = new InsertingStream injection.search, injection.append, writeToClient
          (chunk) ->
            return writeToClient null if chunk is null
            inserter.write chunk
        console.error "  bugging '#{fullurl}'"
      if proxy_response.headers['content-encoding'] is 'gzip'
        console.error "  unzipping"
        delete proxy_response.headers['content-encoding']
        writeToClient = do (writeToClient) ->
          unzipper = createGunzip()
          unzipper.on 'data', writeToClient
          unzipper.on 'end', -> writeToClient null
          (chunk) ->
            return unzipper.end() if chunk is null
            unzipper.write chunk
    proxy_response.addListener 'data', writeToClient
    proxy_response.addListener 'end', -> writeToClient null
    delete proxy_response.headers['content-length']
    delete proxy_response.headers['content-range']
    response.writeHead proxy_response.statusCode, proxy_response.headers
  request.addListener 'data', (chunk) -> proxy_request.write chunk
  request.addListener 'end', -> proxy_request.end()
  console.log "✓ #{showurl}" if logging

# Activate it.
http.createServer(server_cb).listen 8421, '127.0.0.1'

# Load the injection commands.
fs.readdir 'injections', (err, files) ->
  throw err if err
  files = (file for file in files when ~file.search /\.coffee$/)
  async.forEachSeries files, (file, fileLoaded) ->
    fs.readFile 'injections/' + file, 'utf8', (err, data) ->
      throw err if err
      try
        fileContent = coffee.eval data
      catch evalE
        console.error "broken: "+file
        return
      if not fileContent?
        throw "gnarf"
      injections.push fileContent
      console.error "loaded injection configfile #{file}"
      fileLoaded()
  , (err) ->
    throw err if err
    console.error 'successfully loaded injection configuration'

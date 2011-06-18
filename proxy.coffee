coffee = require 'coffee-script'

async = require 'async'
fs = require 'fs'
http = require 'http'
{checkURL} = require './urlcheck'
{InsertingStream} = require './streaminsert'

console.error = ->

# Script injections (scripts to insert into server->client data)
injections = []

proxyUrlRegex = /^http:\/\/([^\/]*)\/(.*)$/

denyRequest = (response, reason, code = 403) ->
  response.writeHead code
  response.write reason, 'utf8'
  response.end()

# Prepare the proxy.
server_cb = (request, response) ->
  [host] = request.headers.host.split ':'
  delete request.headers['accept-encoding']
  request.headers['accept-charset'] = 'utf-8'
  if 0 is request.url.indexOf 'http://'
    [_, host, request.url] = proxyUrlRegex.exec request.url
    request.url = '/' + request.url
  fullurl = "#{host}#{request.url}"
  
  {block, blockReason} = checkURL fullurl
  if block
    console.error "blocked request for '#{fullurl}', reason: #{blockReason}"
    return denyRequest response, blockReason
  
  proxy_request = http.request
    method: request.method
    path: request.url
    headers: request.headers
    host: host
    port: 80
  proxy_request.on 'error', (err) ->
    denyRequest response, err+'', 404
  proxy_request.addListener 'response', (proxy_response) ->
    writeToClient = (chunk) -> response.write chunk
    console.error "request for '#{fullurl}'"
    #console.error "  HEADERS: #{JSON.stringify request.headers}"
    if not proxy_response.headers["content-type"]?.indexOf("text/")
      for injection in injections when ~fullurl.search injection.urlregex
        writeToClient = do (writeToClient) ->
          inserter = new InsertingStream injection.search, injection.append, writeToClient
          (chunk) -> inserter.write chunk
        console.error "  bugging '#{fullurl}'"
    proxy_response.addListener 'data', writeToClient
    proxy_response.addListener 'end', -> response.end()
    delete proxy_response.headers['content-length']
    delete proxy_response.headers['content-range']
    response.writeHead proxy_response.statusCode, proxy_response.headers
  request.addListener 'data', (chunk) -> proxy_request.write chunk
  request.addListener 'end', -> proxy_request.end()

# Activate it.
http.createServer(server_cb).listen 8421

# Load the injection commands.
fs.readdir 'injections', (err, files) ->
  throw err if err
  files = (file for file in files when ~file.search /\.coffee$/)
  async.forEachSeries files, (file, fileLoaded) ->
    fs.readFile 'injections/' + file, 'utf8', (err, data) ->
      throw err if err
      fileContent = coffee.eval data
      if not fileContent?
        throw "gnarf"
      injections.push fileContent
      console.error "loaded injection configfile #{file}"
      fileLoaded()
  , (err) ->
    throw err if err
    console.error 'successfully loaded injection configuration'

fs = require 'fs'

blacklist = []

split2 = (str, delimiter) ->
  i = str.indexOf delimiter
  if ~i
    [str.substring(0, i), str.substring(i+1)]
  else
    null

endsWith = (haystack, needle) ->
  haystack.length - needle.length >= 0 and haystack.length - needle.length is haystack.lastIndexOf needle

exports.checkURL = (url) ->
  [host] = url.split '/', 1
  for {type, data: needle} in blacklist
    hit = switch type
      when 'raw' then ~url.indexOf needle
      when 'host' then endsWith host, needle
      else throw "this shouldn't happen"
    if hit
      return {
        block: true
        blockReason: "blocked by '#{needle}'"
      }
  block: false

parseBlacklist = (text) ->
  blacklist = for line in text.split '\n'
    line = line.trim()
    continue if 0 is line.indexOf '#'
    continue if line.length is 0
    if entry = split2 line, ' '
      [type, data] = entry
      if not type in ['raw', 'host']
        throw 'unknown entry type'
      {type, data}
    else
      throw "invalid line: #{line}"

fs.readFile 'blacklist.txt', 'utf8', (err, data) ->
  throw err if err
  parseBlacklist data
  console.error "loaded blacklist"

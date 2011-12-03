{EventEmitter} = require 'events'

bufInsert = (buf, i, buf2) ->
  newbuf = new Buffer buf.length + buf2.length
  buf.copy newbuf, 0, 0, i
  buf2.copy newbuf, i
  buf.copy newbuf, i+buf2.length, i
  newbuf

exports.InsertingStream = class InsertingStream extends EventEmitter
  constructor: (searchString, appendString, callback) ->
    @searchBuffer = new Buffer searchString
    console.error "  searching for '#{searchString}'"
    @appendBuffer = new Buffer appendString
    # This is the next expected character.
    # Position 0 means: Expect the first character.
    @searchPositions = [0]
    if callback?
      @on 'data', callback
  
  write: (chunk) ->
    i = 0
    #console.log "chunktype: #{chunk.constructor.name}"
    while i < chunk.length
      byte = chunk[i]
      # can't write this as a comprehension because of a CS bug
      # (see https://github.com/jashkenas/coffee-script/issues/1222)
      oldSearchPositions = @searchPositions
      @searchPositions = [0]
      for searchPosition in oldSearchPositions
        expectedByte = @searchBuffer[searchPosition]
        if byte is expectedByte
          searchPosition++
          if searchPosition is @searchBuffer.length
            chunk = bufInsert chunk, i+1, @appendBuffer
            console.error '  inserting...'
            continue
          @searchPositions.push searchPosition
      i++
    @_write chunk
  
  _write: (chunk) ->
    #console.error "inserting stream writes data"
    @emit 'data', chunk

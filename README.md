What is it?
===========
node-filterproxy is a filtering and streaming HTTP proxy. It can:

 - block requests by server hostname
 - block requests by URL
 - inject things in pages when URL and content match (works without completely
   buffering the response!)

Injection works this way: Whenever a response comes in and its URL matches a
configured injection, the response stream will be watched in order to find
the trigger byte sequence. Upon finding such a trigger sequence, a predefined
other byte sequence will be injected in the stream.

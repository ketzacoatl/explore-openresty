## Exploring Lua and Nginx

This is a series of examples that explore Lua + Nginx via Openresty.

The goal is to demonstrate a basic webapp that processes JSON POSTs over HTTP
via a message queue and data processing sink, eventually storing those messages
in a Postgres database.

See `dev-notes.md` for the juicy details that steps through each of the examples.


### Examples

After drawing up a basic design to implement for the demo, I wrote out a list of
topics that I would need to sort out as a Lua/Openresty newb.

These exercises encompass:

* 01-hello-world-html
* 02-hello-world-json
* 03-echo-post-json
* 04-write-to-postgres
* 05-dynamic-db-connection-info
* 06-connect-to-redis
* 07-redis-data-sink
* 08-limit-http-methods
* 09-batch-read-from-postgres
* 10-basic-http-client
* 11-batch-submit-posts
* stand-alone-lua-image


### The Demo

See `demo/README.md` for more details on running the POST processing, message
queue demo.

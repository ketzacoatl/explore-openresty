## Introduction to Webapp Development with Lua and Openresty

This is a series of posts that aim to explore the basics of webapp development
with Lua and Openresty. While I have read a bit about Lua and Openresty in the
past, I have no real experience with the stack. The purpose of these posts is
to document my explorations, and to do so in a way that might help you explore
similar topics.

Openresty is built on nginx, so we'll be using lua with nginx. We'll use
postgres as a database, and may explore redis, rabbitmq, or similar services.
For simplicity, we'll build Docker images and run the exercises in containers.

I have a difficult time learning how to use a new language, stack, or framework
if the examples are not following topics you find in the real-world of webapp
development. While this series will be introductory, we will aim to produce
a small cluster of services that demonstrate the basic components of a
meaningful data transaction/processing workflow.

In pursuit of that demo, each post in the series will focus on a specific goal,
building up from very basic to more meaningful capabilities, eventually coming
together to form the demo. We will refer to this as the Task.


### Task Overview

* Set up a basic message queue system using
  * nginx
  * Lua
  * a message queue of some sort
  * PostgreSQL database
* The application should accept arbitrary strings of data to be POSTed to it, which it should then put on the message queue.
* A sink should be connected to the message queue which processes the items and stores them in the database.
* The message queue should be highly available (two or more nodes) and should gracefully handle a single node failure.
* The service you create should work as specified below.
  - Nginx listens on the /post location for POST requests. The format of the POST data is entirely up to you to decide. The data that is POSTed should eventually be persisted to the database.
  - Nginx listens on the /get location for GET requests. The response should contain the last 100 pieces of data that was POSTed.
  - The application logic is written in Lua and runs inside nginx.
* Assume the nginx server, message queue and database servers all run on separate machines. For the purpose of testing it’s perfectly fine to install everything on a single machine, **just don’t assume you can connect to localhost at the application layer**.


### Initial Thoughts / Concerns / Design Ideas

* I've never used lua/nginx/openresty, but having setup lots of django + nginx + uwsgi + pgsql, I've been really intrigued by the stack, so this is an exciting challenge.
* Break-down into the following components:
  * DB: Postgres
  * API Server (Webapp/frontend) - nginx + lua w/ 2 primary endpoints
  * Redis/RabbitMQ/ZeroMQ/etc as the messaging middleware, tmp storage, etc
  * Workers - MsgPoster - stand-alone lua script/executable that pulls from queue and writes msg to the db.
* The primary open question is with the Message Queue, which to use with lua and how to do so.


* The stand-alone script/executable will need to be figured out
  * CLI parameters
  * I've seen a bunch of `lua foo.lua` - research static compilation
* When running lua in nginx, wire in the module at nginx.conf level, app source has defaults for settings, nginx.conf defines custom parameters
  - where-as with cli/script we need use cli parameters/args to tell app what to do
* For speed and flexibility in making this initial implementation, use docker for each component (pg, queue, nginx webapp, worker), and run dev/demo with docker-compose
  * could also use vagrant or mini-kube but I'm low on desktop resources ATM and most of what I will spend time on here needs to go to working with the newness of lua (not orchestrating the group of services, there are many ways to do that, and I can do that later without breaking much of a sweat).

### Initial Questions

* is there a reason to _not_ use openresty for this task?
  * A: openresty is fine
* already using redis, and no rabbitmq, correct?
  * A: redis and rabbit are already both in use, ok to use either
* is there any existing code I should work from?
  * A: nope
* is there an existing queue library for Lua that you would recommend?
  * A: nope

### Initial Tasks

* research
  * lua + nginx, executing arbitrary code for an HTTP URL path
  * lua as a stand-alone executable or calling luascripts in general
  * how to connect lua to [redis, rabbit, ..], and postgres
    * initial connection + read/write data
  * how to respond to new messages in the queue - run `foo()` when there's a new message
  * which {redis,rabbitmq,etc} is _most often_ connected to lua?
    * which seem to have the strongest client libraries?
  * read envvars from lua
    * http://stackoverflow.com/questions/7633397/print-list-of-all-environment-variables
    * "use luaex" - https://github.com/LuaDist/luaex
    * maybe easier to use cliargs.. we'll see
  * queues and lua


* hello world examples
  * nginx + lua for `/foo` - completed 03/02
  * lua print hello world - completed 02/??
* stand-alone script using CLI args/envvars to set variables
  * for hostnames/credentials/etc
* parse POST data (JSON) in nginx + lua - completed 03/02
* connect to postgres and write data to a table - completed 03/02
* connect to postgres and read data from a table - completed 03/02
  * not using https://github.com/FRiCKLE/ngx_postgres, but do so with lua from nginx
  * https://github.com/leafo/pgmoon#handling-json - retrieve JSON and get it in lua
* connect to queue and read data
* connect to a queue and write data
* make it easy to swap one queue for another
* make file to build and run docker images / etc - started doing this with exercise 4, easier workflow
* script creating tables and loading data into postgres - completed 03/02
  * can just use the postgres image's support for auto-running `.sql`/`.sh` in db init path

### Notes from Initial explorations

* openresty has a docker image built on alpine: `openresty/openresty:alpine`
  * https://hub.docker.com/r/openresty/openresty/
  * there is the `alpine-fat` tag which includes `luarocks`
* example building alpine docker image with lua
  * https://github.com/pirogoeth/alpine-lua/blob/master/versions/5.2/Dockerfile
* library for standard stuff that isn't in lua core
  * https://github.com/stevedonovan/Penlight
  * TIL: lua core maps to c stdlib (that's it)
* library for CLI arg parse
  * https://github.com/amireh/lua_cliargs
* can build custom static executable with `luastatic`:
  * https://github.com/ers35/luastatic
* general openresty/nginx and "programming in lua" docs
  * http://www.lua.org/pil/contents.html
  * http://lua-users.org/
    * wiki: http://lua-users.org/wiki/
  * https://openresty.org/download/agentzh-nginx-tutorials-en.html
  * https://openresty.gitbooks.io/programming-openresty/content/
* django-like webapp framework building on openresty
  * http://leafo.net/lapis/




## Plan of Attack

* use docker for development, setup and demo
* write lua code to read from database and respond to GET, integrate into nginx
* write lua to accept JSON - `{"msg": "...."}` - write to POST to the queue, integrate into nginx
* write stand-alone script to watch the queue, write msg to DB when there's a message in the queue
  * if a msg fails to write to the database, then write the msg to log/stdout
* most of my time will be spent working with lua, integrating with the database and the queue
* start with redis as a queue, but only b/c it is easier/simpler to start with (fewer knobs)
  * should be easy to swap queues and queue-processing strategy
* guard for race conditions and data-loss during processing of items on the queue
  * see "Reliable Queue" in https://redis.io/commands/rpoplpush
* not sure how to use redis as a dumb KV with push/pop vs using some sort of smarter queuing framework on top of redis (or embedded within), will need to figure this out as I get further along



### Redis Queue Bindings / Options

* https://github.com/ocallaco/redis-queue
  * queue built on redis.. promising, but hasn't been updated in 3 _years_...
* https://github.com/nrk/redis-lua
  * redis client, hasn't been updated in _5 years..._
* https://github.com/openresty/redis2-nginx-module
  * not really what I'm looking for..
  * nor https://www.nginx.com/resources/wiki/modules/redis/

### RabbitMQ Lua Bindings

* https://github.com/wingify/lua-resty-rabbitmqstomp
  * "opinionated", but it's moved a lot of traffic...
* https://github.com/cthulhuology/amqp.lua

### Or combine Redis + RabbitMQ...

http://engineering.wingify.com/posts/scaling-with-queues/



### Consider putting the lua script right into redis?

This doesn't seem to be the best fit - https://redislabs.com/ebook/part-3-next-steps/chapter-11-scripting-redis-with-lua/ - but it's probably possible to put lua script in redis that responds to the additional messages added to the queue.. I'm not too excited about this route for a few reasons:

* there's a bunch to learn with scripting in redis, higher initial entrance fee (at least for now)
* if the code to respond to the queue is in redis, we have to add redis nodes to add workers, which isn't graceful and doesn't scale

That said, http://uniformlyrandom.com/2012/10/20/distributed-scheduled-queue-with-redis/ is really interesting - even includes some lua to embed in redis and demonstrates a distributed scheduled queue.



### Interesting Openresty Modules

* https://github.com/openresty/lua-resty-redis
  * redis client, actively maintained :)
* https://github.com/openresty/lua-redis-parser#readme
  * parser for redis responses?
* https://github.com/bungle/lua-resty-reqargs
  * form and JSON processing
* https://github.com/bungle/lua-resty-validation
* https://github.com/leafo/pgmoon
  * postgres client
* https://github.com/garethr/nginx-json-proxy
* https://libraries.io/github/bungle/awesome-resty
  * HUGE list of awesome modules

### JSON + POST + nginx + lua

* http://stackoverflow.com/a/22788730
* https://github.com/bungle/lua-resty-reqargs

### JSON + nginx + lua (responses)

* http://blog.zot24.com/return-json-responses-when-using-openresty-lua/



## Notes Hacking and Exploring



### Add SSL to alpine

```
/ # update-ca-certificates
WARNING: ca-certificates.crt does not contain exactly one certificate or CRL: skipping
/ # wget https://github.com/amireh/lua_cliargs/raw/master/examples/03_config_file.lua
Connecting to github.com (192.30.253.112:443)
wget: can't execute 'ssl_helper': No such file or directory
wget: error getting response: Connection reset by peer
/ # apk add wget
(1/1) Installing wget (1.18-r1)
Executing busybox-1.25.1-r0.trigger
OK: 216 MiB in 47 packages
/ # wget -q https://github.com/amireh/lua_cliargs/raw/master/examples/03_config_file.lua
/ # ls -Alh *.lua
-rw-r--r--    1 root     root        1.7K Feb 28 14:09 03_config_file.lua
```



## Lua hello world - stand-alone



### Fiddle with lua_cliargs

```
/ # wget -q https://github.com/amireh/lua_cliargs/raw/master/examples/00_general.lua
/ # /usr/local/openresty/luajit/bin/luajit 00_general.lua
cli_example.lua: bad number of arguments: 1-4 argument(s) must be specified, not 0; re-run with help for usage
/ # /usr/local/openresty/luajit/bin/luajit 00_general.lua  -h
cli_example.lua: Usage: cli_example.lua [OPTIONS] [--] OUTPUT [INPUTS-1 [INPUTS-2 [...]]]

ARGUMENTS:
  OUTPUT                path to the output file (required)
  INPUTS                the source files to read from (optional,
                        default: nil)

OPTIONS:
  -c, --compress=FILTER the filter to use for compressing output: gzip,
                        lzma, bzip2, or none (default: gzip)
  -d                    script will run in DEBUG mode
  -v, --version         prints the program's version and exits
  --verbose             the script output will be very verbose
  --[no-]ice-cream      ice cream, or not (default: on)
; re-run with help for usage
```



### Installing luastatic

Using alpine, `luarocks` doesn't write out it's package index/manifests and fails to install `luastatic` - really annoying:

```
ᐅ docker run --rm -it alpine /bin/sh -c "apk add --update luarocks5.1 && luarocks-5.1 search luastatic"
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/community/x86_64/APKINDEX.tar.gz
(1/3) Installing lua5.1-libs (5.1.5-r2)
(2/3) Installing lua5.1 (5.1.5-r2)
(3/3) Installing luarocks5.1 (2.4.2-r0)
Executing busybox-1.25.1-r0.trigger
OK: 5 MiB in 14 packages
Warning: Failed searching manifest: Failed fetching manifest for https://luarocks.org - Failed downloading https://luarocks.org/manifest - /root/.cache/luarocks/https___luarocks.org/manifest
Warning: Failed searching manifest: Failed fetching manifest for https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/ - Failed downloading https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/manifest - /root/.cache/luarocks/https___raw.githubusercontent.com_rocks-moonscript-org_moonrocks-mirror_master_/manifest
Warning: Failed searching manifest: Failed fetching manifest for http://luafr.org/moonrocks/ - Failed downloading http://luafr.org/moonrocks/manifest - /root/.cache/luarocks/http___luafr.org_moonrocks_/manifest
Warning: Failed searching manifest: Failed fetching manifest for http://luarocks.logiceditor.com/rocks - Failed downloading http://luarocks.logiceditor.com/rocks/manifest - /root/.cache/luarocks/http___luarocks.logiceditor.com_rocks/manifest

Search results:
===============

```

I could get this to work with Ubuntu:

```
ᐅ docker run --rm -it ubuntu:trusty /bin/bash
root@5eb950b525c7:/# apt-get update
root@5eb950b525c7:/# apt-cache search luarocks
luarocks - deployment and management system for Lua modules
root@5eb950b525c7:/# apt-get install luarocks
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following extra packages will be installed:
...
root@5eb950b525c7:/# luarocks install luastatic
Installing http://luarocks.org/repositories/rocks/luastatic-0.0.6-2.src.rock...
Using http://luarocks.org/repositories/rocks/luastatic-0.0.6-2.src.rock... switching to 'build' mode
Archive:  /tmp/luarocks_luarocks-rock-luastatic-0.0.6-2-7727/luastatic-0.0.6-2.src.rock
  inflating: luastatic-0.0.6-2.rockspec
   creating: luastatic/
   ...
   extracting: luastatic/test/subdir_binmodule.lua
   inflating: luastatic/test/binmodule_multiple.c
Updating manifest for /usr/local/lib/luarocks/rocks

luastatic 0.0.6-2 is now built and installed in /usr/local/ (license: CC0)
```

Ubuntu is annoyingly slow and heavy after using alpine, so let's see what the `openresty/openresty:alpine-fat` image is like here:

```
ᐅ docker run --rm -it --entrypoint /bin/sh openresty/openresty:alpine-fat
/ #
/ # which luarocks
/ # which lua
/ # find / -type f -name luarocks*
/usr/local/openresty/luajit/bin/luarocks-admin-5.1
/usr/local/openresty/luajit/bin/luarocks-5.1
/ # /usr/local/openresty/luajit/bin/luarocks-5.1 install luastatic
Installing https://luarocks.org/luastatic-0.0.6-2.src.rock...
Using https://luarocks.org/luastatic-0.0.6-2.src.rock... switching to 'build' mode
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
No existing manifest. Attempting to rebuild...
luastatic 0.0.6-2 is now built and installed in /usr/local/openresty/luajit (license: CC0)
```

```
/ # /usr/local/openresty/luajit/bin/luastatic -h
luastatic 0.0.6
usage: luastatic main.lua[1] require.lua[2] liblua.a[3] library.a[4] -I/include/lua[5] [6]
  [1]: The entry point to the Lua program
  [2]: One or more required Lua source files
  [3]: The path to the Lua interpreter static library
  [4]: One or more static libraries for a required Lua binary module
  [5]: The path to the directory containing lua.h
  [6]: Additional arguments are passed to the C compiler
```

great!

### Fiddling with luastatic to build a stand-alone executable

```
/ # /usr/local/openresty/luajit/bin/luastatic 00_general.lua
cc -Os 00_general.lua.c   -rdynamic -lm   -o 00_general
00_general.lua.c:5:21: fatal error: lauxlib.h: No such file or directory
 #include <lauxlib.h>
                     ^
compilation terminated.
```

```
/ # /usr/local/openresty/luajit/bin/luastatic 00_general.lua -I/usr/local/openresty/luajit/lib/lua
cc -Os 00_general.lua.c   -rdynamic -lm  -I/usr/local/openresty/luajit/lib/lua -o 00_general
00_general.lua.c:5:21: fatal error: lauxlib.h: No such file or directory
 #include <lauxlib.h>
                     ^
compilation terminated.
```

I see examples on https://github.com/ers35/luastatic like:

```
luastatic main.lua /usr/lib/x86_64-linux-gnu/liblua5.2.a -I/usr/include/lua5.2
```

and... "if you use luaopen_()", or "want statically link with muscl libc..." there are other variants. While I am confident I can get that to work, it's not a task for now. Based on this, and being able to easily use `lua foo.lua` with lua in the alpine images, I'm going to skip using luastatic for now - that is a better polishing task, one to defer until later.



### Going back to lua_cliargs for a moment...

The first example I used (above) was super minimal, the [03 example](https://github.com/amireh/lua_cliargs/blob/master/examples/03_config_file.lua) reads from a config file and has more dependencies, which makes it a good candidate for my next steps..

Grab the source:

```
/ # wget -q https://github.com/amireh/lua_cliargs/raw/master/examples/03_config_file.lua
```

Test it:

```
/ # /usr/local/openresty/luajit/bin/luajit 03_config_file.lua
/usr/local/openresty/luajit/bin/luajit: 03_config_file.lua:1: module 'cliargs' not found:
	no field package.preload['cliargs']
	no file './cliargs.lua'
	no file '/usr/local/openresty/luajit/share/luajit-2.1.0-beta2/cliargs.lua'
	no file '/usr/local/share/lua/5.1/cliargs.lua'
	no file '/usr/local/share/lua/5.1/cliargs/init.lua'
	no file '/usr/local/openresty/luajit/share/lua/5.1/cliargs.lua'
	no file '/usr/local/openresty/luajit/share/lua/5.1/cliargs/init.lua'
	no file './cliargs.so'
	no file '/usr/local/lib/lua/5.1/cliargs.so'
	no file '/usr/local/openresty/luajit/lib/lua/5.1/cliargs.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'
stack traceback:
	[C]: in function 'require'
	03_config_file.lua:1: in main chunk
	[C]: at 0x7f448eb90bd0
```

Looks like we need to install that cliargs package, or make it available in some other way. Let's look at luarocks..

```
/ # /usr/local/openresty/luajit/bin/luarocks install cliargs

Error: No results matching query were found.
```

OK, let's search...

```
/ # /usr/local/openresty/luajit/bin/luarocks search cliargs

Search results:
===============


Rockspecs and source rocks:
---------------------------

lua_cliargs
   3.0-1 (rockspec) - https://luarocks.org
   3.0-1 (src) - https://luarocks.org
   3.0-0 (rockspec) - https://luarocks.org
   ...
```

OK, so let's install `lua_cliargs`...

```
/ # /usr/local/openresty/luajit/bin/luarocks install lua_cliargs
Installing https://luarocks.org/lua_cliargs-3.0-1.src.rock...
Using https://luarocks.org/lua_cliargs-3.0-1.src.rock... switching to 'build' mode
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
lua_cliargs 3.0-1 is now built and installed in /usr/local/openresty/luajit (license: MIT <http://opensource.org/licenses/MIT>)
```

and re-run the example...

```
/ # /usr/local/openresty/luajit/bin/luajit 03_config_file.lua
/usr/local/openresty/luajit/bin/luajit: 03_config_file.lua:2: module 'pl.tablex' not found:
	no field package.preload['pl.tablex']
	no file './pl/tablex.lua'
	no file '/usr/local/openresty/luajit/share/luajit-2.1.0-beta2/pl/tablex.lua'
	no file '/usr/local/share/lua/5.1/pl/tablex.lua'
	no file '/usr/local/share/lua/5.1/pl/tablex/init.lua'
	no file '/usr/local/openresty/luajit/share/lua/5.1/pl/tablex.lua'
	no file '/usr/local/openresty/luajit/share/lua/5.1/pl/tablex/init.lua'
	no file './pl/tablex.so'
	no file '/usr/local/lib/lua/5.1/pl/tablex.so'
	no file '/usr/local/openresty/luajit/lib/lua/5.1/pl/tablex.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'
	no file './pl.so'
	no file '/usr/local/lib/lua/5.1/pl.so'
	no file '/usr/local/openresty/luajit/lib/lua/5.1/pl.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'
stack traceback:
	[C]: in function 'require'
	03_config_file.lua:2: in main chunk
	[C]: at 0x7f7beafacbd0
```

hrm.. tablex eh? DDG that and find [Penlight](https://github.com/stevedonovan/Penlight) - a "batteries included" library to expand on the stdlib - so let's try to install that..

```
/ # /usr/local/openresty/luajit/bin/luarocks install penlight
Installing https://luarocks.org/penlight-1.4.1-1.rockspec...
Using https://luarocks.org/penlight-1.4.1-1.rockspec... switching to 'build' mode

Missing dependencies for penlight:
luafilesystem

Using https://luarocks.org/luafilesystem-1.6.3-2.src.rock... switching to 'build' mode
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c src/lfs.c -o src/lfs.o
gcc -shared -o lfs.so -L/usr/local/openresty/luajit/lib src/lfs.o
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
luafilesystem 1.6.3-2 is now built and installed in /usr/local/openresty/luajit (license: MIT/X11)

Archive:  penlight-1.4.1.zip
63eb42d1961586789f1952ec2873cbf309c52847
   creating: penlight-1.4.1/
   ...
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
penlight 1.4.1-1 is now built and installed in /usr/local/openresty/luajit (license: MIT/X11)
```

Re-run again..

```
/ # /usr/local/openresty/luajit/bin/luajit 03_config_file.lua
false
```

YAY!

```
/ # /usr/local/openresty/luajit/bin/luajit 03_config_file.lua -h
Usage: [OPTIONS]

OPTIONS:
  --config=FILEPATH path to a config file (default: .programrc)
  --quiet           Do not output anything to STDOUT
```

Unfortunately, this isn't quite working with a cliarg...

```
/ # /usr/local/openresty/luajit/bin/luajit 03_config_file.lua --config=00_general.lua
cli_example.lua: unknown/bad option: --config=00_general.lua; re-run with help for usage

```

...but I think this might have something to do with using `luajit` instead of `lua`.

let's try with `lua` directly... add it first:

```
/ # apk add lua
(1/3) Installing lua5.1-libs (5.1.5-r2)
(2/3) Installing lua5.1 (5.1.5-r2)
(3/3) Installing lua (5.1.5-r4)
Executing busybox-1.25.1-r0.trigger
OK: 216 MiB in 50 packages
```

and run the example with `lua`:

```
/ # lua 00_general.lua
lua: 00_general.lua:10: module 'cliargs' not found:
	no field package.preload['cliargs']
	no file './cliargs.lua'
	no file '/usr/local/share/lua/5.1/cliargs.lua'
	no file '/usr/local/share/lua/5.1/cliargs/init.lua'
	no file '/usr/local/lib/lua/5.1/cliargs.lua'
	no file '/usr/local/lib/lua/5.1/cliargs/init.lua'
	no file '/usr/share/lua/5.1/cliargs.lua'
	no file '/usr/share/lua/5.1/cliargs/init.lua'
	no file './cliargs.so'
	no file '/usr/local/lib/lua/5.1/cliargs.so'
	no file '/usr/lib/lua/5.1/cliargs.so'
	no file '/usr/local/lib/lua/5.1/loadall.so'
stack traceback:
	[C]: in function 'require'
	00_general.lua:10: in main chunk
	[C]: ?
```

that lua doesn't know about the packages we've already installed with the luarocks in openresty.

---

Time Tracking.. since last check: 1 hour;   total: 2 hours

---



## Hello World w/ Lua

Start off with something really simple.. hello world based on openresty + nginx,  embed lua right in nginx config. Nothing special or fancy. Do a version in HTML and then JSON.

### Hello World - HTML Version

```
ᐅ cd examples/01-hello-world-html
ᐅ docker run --rm --volume `pwd`:/usr/local/openresty/nginx/conf/ openresty/openresty:alpine -t
nginx: the configuration file /usr/local/openresty/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/openresty/nginx/conf/nginx.conf test is successful
```

This example embeds the lua directly into `nginx.conf` :

```nginx
worker_processes 1;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen 8000;
        location / {
            default_type text/html;
            content_by_lua '
                ngx.say("<p>hello world!</p>")
            ';
        }
    }
}
```

Let's run it with the `openresty:alpine` docker image:

```
ᐅ docker run --name lua --rm --volume `pwd`:/usr/local/openresty/nginx/conf/ -p 127.0.0.1:8000:8000 openresty/openresty:alpine
```

Let's check it out:

```
ᐅ curl localhost:8000
<p>hello world!</p>
```

### Hello World - JSON Version

The `nginx.conf` this time...

```nginx
worker_processes  1;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            default_type text/html;
            content_by_lua '
                local cjson = require "cjson"
                ngx.status  = ngx.HTTP_OK
                ngx.say(cjson.encode({ status = true, foobar = "string" }))
                return ngx.exit(ngx.HTTP_OK)
            ';
        }
    }
}
```

Run with the same openresty docker image:

```
ᐅ cd examples/02-hello-world-json
ᐅ docker run --name lua --rm --volume `pwd`:/usr/local/openresty/nginx/conf/ -p 127.0.0.1:8000:8000 openresty/openresty:alpine
```

Check it out...

```
ᐅ curl -i localhost:8000
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Thu, 02 Mar 2017 15:43:20 GMT
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":true,"foobar":"string"}
```

### Drop into the docker container to debug...

Open a shell, look for error log, etc...

```
ᐅ docker exec -it lua /bin/sh
/ #
/ # find / -type f -name error.log
/usr/local/openresty/nginx/error.log
/ #
/ # cat /usr/local/openresty/nginx/error.log
2017/03/02 15:40:13 [error] 5#5: *1 lua entry thread aborted: runtime error: content_by_lua(nginx.conf:18):3: attempt to index global 'cjson' (a nil value)
stack traceback:
coroutine 0:
        content_by_lua(nginx.conf:18): in function <content_by_lua(nginx.conf:18):1>, client: 172.17.0.1, server: , request: "GET / HTTP/1.1", host: "localhost:8000"
```

Reload nginx...

```
ᐅ docker exec -it lua /usr/local/openresty/nginx/sbin/nginx -s reload
2017/03/02 15:47:19 [notice] 7#7: signal process started
```

### Fail to install resty-reqargs with OPM, works with luarocks

fails:

```
/usr/local/openresty # ./bin/opm get bungle/lua-resty-reqargs
* Fetching bungle/lua-resty-reqargs
  Downloading https://opm.openresty.org/api/pkg/tarball/bungle/lua-resty-reqargs-1.4.opm.tar.gz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  5585  100  5585    0     0   3777      0  0:00:01  0:00:01 --:--:--  3986
Package lua-resty-upload-0.09 already installed.
ERROR: openresty is required but is not available according to resty:
```

works:

```
/usr/local/openresty # ./luajit/bin/luarocks install lua-resty-reqargs
Installing https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock...
Using https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock... switching to 'build' mode
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
No existing manifest. Attempting to rebuild...
lua-resty-reqargs 1.4-1 is now built and installed in /usr/local/openresty/luajit (license: BSD)
```

"fails" and "works" also refers to the result in nginx (eg, can nginx find and use the module).

## Read JSON POST'd to nginx

For this one, we need to install a module for openresty, so we'll build a Docker image with that module installed:

```
ᐅ cd 03-echo-post-json
ᐅ docker build --tag echo-post .
Sending build context to Docker daemon 16.38 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Running in a66afb2f9eec
 ---> 35a8c6e42825
Removing intermediate container a66afb2f9eec
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Running in a6391012a357
Installing https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock...
Using https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock... switching to 'build' mode
No existing manifest. Attempting to rebuild...
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
lua-resty-reqargs 1.4-1 is now built and installed in /usr/local/openresty/luajit (license: BSD)

 ---> d5c51f61f244
Removing intermediate container a6391012a357
Step 4 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> 25979be278f7
Removing intermediate container f4671c37c97b
Successfully built 25979be278f7
```

OK, that will tag the image with `echo-post` (you can give it another name if you like..)

```
ᐅ docker images | grep echo-post
echo-post        latest         25979be278f7        About a minute ago   243.6 MB
```

Run it:

```
ᐅ docker run --name lua --rm -p 127.0.0.1:8000:8000 echo-post
```

Let's POST some JSON and see the echo:

```
ᐅ curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/
{"password":"xyz","username":"xyz"}

ᐅ curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz", "foobar":{"foo": "bar"}}' localhost:8000/
{"password":"xyz","username":"xyz","foobar":{"foo":"bar"}}

ᐅ curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz", "foobar":{"foo": "bar",}}' localhost:8000/
{}
```

Here is the `nginx.conf` with embedded lua:

```nginx
worker_processes  1;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            default_type text/html;
            content_by_lua '
                local cjson = require "cjson"
                local get, post, files = require "resty.reqargs"()
                ngx.status  = ngx.HTTP_OK
                ngx.say(cjson.encode(post))
                return ngx.exit(ngx.HTTP_OK)
            ';
        }
    }
}
```

The `Dockerfile` is also very simple:

```Dockerfile
FROM openresty/openresty:alpine-fat
EXPOSE 8000
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
```

---

Time Tracking: since last check: 1.5 hours;   total: 3.5 hours

---

### Connect to db, and write to table (from nginx)

We're going to need a second container for this, to run postgres. There is a `postgres:alpine` variant of the image, and we'll use that. The postgres image will auto-run `*.sh` or `*.sql` that are in the `/init` path in the image - we'll rely on this to auto-create the tables (and in future exercises, to load initial data fixtures) for us.

Thus, with two docker builds and containers to run, it's time for a `Makefile`:

```
build:
        docker build --tag=db  --rm=true ./db
        docker build --tag=app --rm=true ./app

run:
        docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db
        docker run -d --name app --net host -p 127.0.0.1:8000:8000 app

clean:
        docker stop db  || true
        docker stop app || true
        docker rm   db  || true
        docker rm   app || true

reload:
        docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
        docker exec -it app tail -f /usr/local/openresty/nginx/error.log

cat-posts:
        docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
```

Building the images with `make build`:

```
ᐅ make build
docker build --tag=db  --rm=true ./db
Sending build context to Docker daemon 15.87 kB
Step 1 : FROM postgres:alpine
 ---> f0476a087b97
Step 2 : ENV POSTGRES_PASSWORD password
 ---> Running in 08b1c7802a49
 ---> 5324840fb862
Removing intermediate container 08b1c7802a49
Step 3 : ENV POSTGRES_DB lua-app
 ---> Running in 52f3111e0f3f
 ---> 126f7a77f9eb
Removing intermediate container 52f3111e0f3f
Step 4 : ADD init.sql /docker-entrypoint-initdb.d/
 ---> d1294db462c4
Removing intermediate container ae40bad2713a
Step 5 : RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
 ---> Running in 1b4276876287
 ---> e18cb105e24c
Removing intermediate container 1b4276876287
Successfully built e18cb105e24c
docker build --tag=app --rm=true ./app
Sending build context to Docker daemon 18.94 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
 ---> Running in 0e09ca9916e8
Installing https://luarocks.org/pgmoon-1.8.0-1.src.rock...

Missing dependencies for pgmoon:
lpeg

Using https://luarocks.org/pgmoon-1.8.0-1.src.rock... switching to 'build' mode
Using https://luarocks.org/lpeg-1.0.1-1.src.rock... switching to 'build' mode
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lpcap.c -o lpcap.o
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lpcode.c -o lpcode.o
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lpprint.c -o lpprint.o
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lptree.c -o lptree.o
gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lpvm.c -o lpvm.o
gcc -shared -o lpeg.so -L/usr/local/openresty/luajit/lib lpcap.o lpcode.o lpprint.o lptree.o lpvm.o
No existing manifest. Attempting to rebuild...
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
lpeg 1.0.1-1 is now built and installed in /usr/local/openresty/luajit (license: MIT/X11)

Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
pgmoon 1.8.0-1 is now built and installed in /usr/local/openresty/luajit (license: MIT)

 ---> 1373c0014b0f
Removing intermediate container 0e09ca9916e8
Step 4 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Running in 22f051a9d6d4
Installing https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock...
Using https://luarocks.org/lua-resty-reqargs-1.4-1.src.rock... switching to 'build' mode
Updating manifest for /usr/local/openresty/luajit/lib/luarocks/rocks
lua-resty-reqargs 1.4-1 is now built and installed in /usr/local/openresty/luajit (license: BSD)

 ---> 999ab5e6968c
Removing intermediate container 22f051a9d6d4
Step 5 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> 03c148603990
Removing intermediate container c7628b45a991
Step 6 : RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
 ---> Running in f777c48e88ee
 ---> 7a6c0f1dbc97
Removing intermediate container f777c48e88ee
Successfully built 7a6c0f1dbc97
```

Run the images as containers:

```
ᐅ make run
docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db
433c5bb9f8287850b833a9ea95c79d738c544e677492de43e14ff42455958230
docker run -d --name app --net host -p 127.0.0.1:8000:8000 app
4f70737f053bec44a5538cb72bba4a2e59ebb4a7beb9231b748ed27d68bb5064
```

```
ᐅ docker ps
CONTAINER ID  IMAGE  COMMAND                 CREATED         STATUS         PORTS  NAMES
4f70737f053b  app    "/usr/local/openresty"  17 seconds ago  Up 17 seconds         app
433c5bb9f828  db     "docker-entrypoint.sh"  17 seconds ago  Up 17 seconds         db
```

Let's check.. did the database create the table we want to see?

```
ᐅ docker exec -it db psql -U postgres -d lua-app
psql (9.6.2)
Type "help" for help.

lua-app=# \dt
         List of relations
 Schema | Name  | Type  |  Owner
--------+-------+-------+----------
 public | posts | table | postgres
(1 row)

lua-app=# ^D\q
```

Let's send in some arbitrary JSON as a POST:

```
ᐅ curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/

HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Fri, 03 Mar 2017 14:07:50 GMT
Content-Type: text/html; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"xyz","username":"xyz"}}
```

Is that in the database?

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id |                  data
----+----------------------------------------
  1 | {"password": "xyz", "username": "xyz"}
(1 row)
```

YAY!

In this example, we can post arbitrary JSON:

```
ᐅ curl -H "Content-Type: application/json" -X POST -d '{"some":"arbitrary","json": {"password":"xyz"}}' localhost:8000/

{"status":"saved","msg":{"some":"arbitrary","json":{"password":"xyz"}}}
```

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id |                        data
----+----------------------------------------------------
  1 | {"password": "xyz", "username": "xyz"}
  2 | {"json": {"password": "xyz"}, "some": "arbitrary"}
(2 rows)
```

If we give it invalid JSON, the situation is handled gracefully:

```
ᐅ curl -H "Content-Type: application/json" -X POST -d '{"invalid": "json"' localhost:8000/

{"status":"saved","msg":{}}
```

However, with the example as it is now, the empty JSON object is written to the database:

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id |                        data
----+----------------------------------------------------
  1 | {"password": "xyz", "username": "xyz"}
  2 | {"json": {"password": "xyz"}, "some": "arbitrary"}
  3 | {}
(3 rows)
```

I'm going to skip over the changes to skip (filter) empty/invalid JSON and respond with a more appropriate error message and status code, but that could be a meaningful improvement.

### Debug connection issues with `pgmoon`

While working on the exercise above, I ran into trouble connecting the lua app to the database:

```nginx
worker_processes  1;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            default_type text/html;
            content_by_lua '
                local cjson = require "cjson"
                local pgmoon = require("pgmoon")
                local pg = pgmoon.new({
                  host     = "db",
                  port     = "5432",
                  user     = "postgres",
                  password = "password",
                  database = "lua-app",
                })
                pg:connect()
                local encode_json = require("pgmoon.json").encode_json
                local get, post, files = require "resty.reqargs"()
                assert(pg:query("INSERT INTO posts (msg) VALUES(" .. encode_json(post) .. ")"))
                ngx.status  = ngx.HTTP_OK
                ngx.say(cjson.encode({status = "saved", msg=post}))
                return ngx.exit(ngx.HTTP_OK)
            ';
        }
    }
}
```

would fail with...

```
2017/03/03 11:10:16 [error] 49#49: *10 attempt to send data on a closed socket: u:0000000041B484A0, c:0000000000000000, ft:8 eof:0, client: 127.0.0.1, server: , request: "POST / HTTP/1.1", host: "localhost:8000"
2017/03/03 11:10:16 [error] 49#49: *10 attempt to receive data on a closed socket: u:0000000041B484A0, c:0000000000000000, ft:8 eof:0, client: 127.0.0.1, server: , request: "POST / HTTP/1.1", host: "localhost:8000"
2017/03/03 11:10:16 [error] 49#49: *10 lua entry thread aborted: runtime error: content_by_lua(nginx.conf:33):14: receive_message: failed to get type: closed
stack traceback:
coroutine 0:
        [C]: in function 'assert'
        content_by_lua(nginx.conf:33):14: in function <content_by_lua(nginx.conf:33):1>, client: 127.0.0.1, server: , request: "POST / HTTP/1.1", host: "localhost:8000"
^Cmake: [logs] Error 130
```

Woah, that's a little confusing! While it _does_ make sense when you know about the details, it took me some hacking around with the code and env in the docker containers to figure out what was going on. Short explanation: the connect is failing, returns nil, and the query is attempted on a socket that is not connected to postgres.

It'd be nice if the error were more clear, and we can help make that happen by wrapping the `pg:connect()` with `assert()`, to end up with: `assert(pg:connect())`. Now the error will be like:

```
2017/03/03 00:19:29 [error] 88#88: *21 lua entry thread aborted: runtime error: content_by_lua(nginx.conf:33):11: no resolver defined to resolve "db"
stack traceback:
coroutine 0:
        [C]: in function 'assert'
        content_by_lua(nginx.conf:33):11: in function <content_by_lua(nginx.conf:33):1>, client: 172.17.0.1, server: , request: "POST / HTTP/1.1", host: "localhost:8000"
```

That's a lot more specific, and gets us closer to the actual issue: the lua script is "unable to find (resolve the hostname) `db`".

To look at what's going on, let's drop into the container and check out the connectivity between the app and db containers:

```
ᐅ docker exec -it app /bin/sh
/ # cat /etc/hosts
172.17.0.3      3751a3f850b9
127.0.0.1       localhost
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
172.17.0.2      db 0c0649632873
/ # ping db
PING db (172.17.0.2): 56 data bytes
64 bytes from 172.17.0.2: seq=0 ttl=64 time=0.139 ms
64 bytes from 172.17.0.2: seq=1 ttl=64 time=0.098 ms
^C
--- db ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.098/0.118/0.139 ms
```

OK, so the container linking works as expected, but lua errors with: `no resolver defined to resolve "db"`. If I use the IP of the linked container, the connection works as expected. This is likely to be an issue with the (super minimal) alpine base image I am using (need some dns utils or some such).

With some research, I found that `/etc/nsswitch.conf` is missing in alpine, and glibc apps may skip consulting `/etc/hosts` (where `db` is defined when using `--link` in docker). Theoretically, adding `hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4` to `/etc/nsswitch.conf` will tell glibc apps to use `/etc/hosts` first. We can then add this to the docker image build (`Dockerfile`), so it is ready to go at runtime:

```Dockerfile
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
```

Here are some helpful resources on this topic:

* http://unix.stackexchange.com/questions/52954/nsswitch-conf-versus-host-conf
* https://github.com/docker-library/golang/pull/76/files
* https://gitlab.com/gitlab-org/gitlab-ci-multi-runner/issues/2142

Updating `/etc/nsswitch.conf` hasn't worked as expected. While I am sure I can dig deeper and resolve that issue, this is an issue I'm going to skip for now. My reasoning is that this is specific to alpine, which is an implementation detail in this exercise, I want to get back to the exercise, and I have a work-around I can use for now.

The work around is to use `--net=host`, bind on `127.0.0.1`, and use that when connecting to the db. In a more "production quality" deployment, I would opt for using consul or similar for service discovery, and would update the alpine images to include consul for DNS lookups.

---

Time Tracking: since last check: 2.5 hours;   total: 6 hours

---

### What has been covered?

* hello world with lua, no nginx
* hello world with openresty
* HTTP response with JSON
* accept and process JSON-formatted POST data
* connect to postgres
* basic queries, writing/selecting data
* luarocks vs opm

### What is next?

* exercise: use cli args (or envvars) to specify db connection details/credentials
* exercise: connect to redis and write some keys (where the key is arbitrary JSON from POST data)
* exercise: connect to redis as a worker/data processing sink, for each new key, print it out
* tie together the various code snippets into lua app for processing GET/POST, and the lua worker for processing new messages in redis

---

### Exercise 5: Use envvars with nginx/lua to set database credentials

```
ᐅ cd examples/05-dynamic-db-connection-info
```



```nginx
worker_processes  1;
env DB_HOST;
env DB_USER;
env DB_PASS;
env DB_NAME;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            default_type text/html;
            content_by_lua '
                local cjson = require "cjson"
                local pgmoon = require("pgmoon")
                local pg = pgmoon.new({
                  host     = os.getenv("DB_HOST"),
                  port     = "5432",
                  user     = os.getenv("DB_USER"),
                  password = os.getenv("DB_PASS"),
                  database = os.getenv("DB_NAME")
                })
                assert(pg:connect())
                local encode_json = require("pgmoon.json").encode_json
                local get, post, files = require "resty.reqargs"()
                assert(pg:query("INSERT INTO posts (data) VALUES(" .. encode_json(post) .. ");"))
                pg:keepalive()
                pg = nil
                ngx.status  = ngx.HTTP_OK
                ngx.say(cjson.encode({status = "saved", msg=post}))
                return ngx.exit(ngx.HTTP_OK)
            ';
        }
    }
}
```

The app's `Dockerfile`:

```dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
ENV DB_HOST 127.0.0.1
ENV DB_USER postgres
ENV DB_PASS password
ENV DB_NAME lua-app
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
```

The database setup is the same as in example 04.

See also

* http://nginx.org/en/docs/ngx_core_module.html#env
* http://lua-users.org/wiki/OsLibraryTutorial

Let's build the images:

```
ᐅ make build
docker build --tag=db:5  --rm=true ./db
Sending build context to Docker daemon 15.87 kB
Step 1 : FROM postgres:alpine
 ---> f0476a087b97
Step 2 : ENV POSTGRES_PASSWORD password
 ---> Using cache
 ---> 30d766415bf6
Step 3 : ENV POSTGRES_DB lua-app
 ---> Using cache
 ---> 449a34987810
Step 4 : ADD init.sql /docker-entrypoint-initdb.d/
 ---> Using cache
 ---> 7ac365dda47a
Step 5 : RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
 ---> Using cache
 ---> 4d1217703d0d
Successfully built 4d1217703d0d
docker build --tag=app:5 --rm=true ./app
Sending build context to Docker daemon  29.7 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : ENV DB_HOST 127.0.0.1
 ---> Using cache
 ---> 38ed960a9c37
Step 4 : ENV DB_USER postgres
 ---> Using cache
 ---> 3c4fe276d25e
Step 5 : ENV DB_PASS password
 ---> Using cache
 ---> 559aba8ee0e1
Step 6 : ENV DB_NAME lua-app
 ---> Using cache
 ---> e9ac50f90e4d
Step 7 : RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
 ---> Using cache
 ---> fbe26dfcccc2
Step 8 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Using cache
 ---> 500183e69a3d
Step 9 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> c57116b5d8a7
Removing intermediate container c7d0caa94d3a
Step 10 : RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
 ---> Running in c178793b094a
 ---> 910139d97922
Removing intermediate container c178793b094a
Successfully built 910139d97922
```

Run:

```
ᐅ make run
docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db:5
34f3178df5f6e47bf87ef95016038561ed43f318bc38287ca8eb8b9764143f16
docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:5
61ef0e0d497c1a443d534a873f54c80debe3ddca1937d2773b07ccd605853e69
```

Test...

```
ᐅ curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/
{"status":"saved","msg":{"password":"xyz","username":"xyz"}}
```

Teardown the running containers with `make clean`.

BTW, we can do something in a stand-alone script as well:

```lua
local host = os.getenv("DB_HOST")
print(host)
```

Run it...

```
ᐅ docker run -it --rm --entrypoint /bin/sh -v `pwd`/app:/src openresty/openresty:alpine
/ # /usr/local/openresty/luajit/bin/luajit /src/worker.lua
nil
/ # DB_HOST=foobar /usr/local/openresty/luajit/bin/luajit /src/worker.lua
foobar
```

### Exercise 6: Connect to Redis!

```
ᐅ cd examples/06-connect-to-redis
```



OK, so instead of the database, let's connect and write our JSON POST data to a redis list (queue):

```nginx
worker_processes  1;
env REDIS_HOST;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            default_type text/html;
            content_by_lua '
                local cjson = require "cjson"
                local redis = require "resty.redis"
                local r     = redis:new()
                local ok, err = r:connect(os.getenv("REDIS_HOST"), 6379)
                if not ok then
                  ngx.say(cjson.encode({status = "error", msg =  "failed to connect: " .. err}))
                  return
                end
                local get, post, files = require "resty.reqargs"()
                assert(r:lpush("queue", cjson.encode(post)))
                r = nil
                ngx.status  = ngx.HTTP_OK
                ngx.say(cjson.encode({status = "saved", msg=post}))
                return ngx.exit(ngx.HTTP_OK)
            ';
        }
    }
}
```

The app's `Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
ENV REDIS_HOST 127.0.0.1
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
```

Build the images:

```
ᐅ make build
docker build --tag=app:6    --rm=true ./
Sending build context to Docker daemon  16.9 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : ENV REDIS_HOST 127.0.0.1
 ---> Using cache
 ---> 43fc68284411
Step 4 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Using cache
 ---> e17bae3848b8
Step 5 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> Using cache
 ---> 306d00c38cee
Step 6 : RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf
 ---> Using cache
 ---> 9ae83b74b72a
Successfully built 9ae83b74b72a
```

Run them:

```
ᐅ make run
docker run -d --name redis  --net host -p 127.0.0.1:6379:6379 redis:6
399c0c7f815d0e4ab7660b7e2852fb64f6f82ec42586c232a70bc11f5b577d2c
docker run -d --name app    --net host -p 127.0.0.1:8000:8000 app:6
39e71e2333452730960e60c09afe4a6ad1bc8f8a4d625f49c2f3859ad1c0634f
```

Send in arbirary JSON to test:

```
ᐅ make test
curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/
{"status":"saved","msg":{"password":"xyz","username":"xyz"}}
```

I repeated that test 4 times, let's see what is in redis:

```
ᐅ make cat-posts
docker exec -it redis redis-cli -c LRANGE queue 0 -1
1) "{\"password\":\"xyz\",\"username\":\"xyz\"}"
2) "{\"password\":\"xyz\",\"username\":\"xyz\"}"
3) "{\"password\":\"xyz\",\"username\":\"xyz\"}"
4) "{\"password\":\"xyz\",\"username\":\"xyz\"}"
```

Yay!

---

Time Tracking: since last check: 1 hour;   total: 7 hours

---

### Get to the bottom of luarocks failing

For a few exercises in this series, I have gone to installing the `lua5.1` and `luarocks-5.1` packages from Alpine's `apk`, but installing a lua module/package with luarocks would fail:

```
/ # luarocks-5.1 search cjson
Warning: Failed searching manifest: Failed fetching manifest for https://luarocks.org - Failed downloading https://luarocks.org/manifest - /root/.cache/luarocks/https___luar
ocks.org/manifest
Warning: Failed searching manifest: Failed fetching manifest for https://raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/ - Failed downloading https:/
/raw.githubusercontent.com/rocks-moonscript-org/moonrocks-mirror/master/manifest - /root/.cache/luarocks/https___raw.githubusercontent.com_rocks-moonscript-org_moonrocks-mir
ror_master_/manifest
Warning: Failed searching manifest: Failed fetching manifest for http://luafr.org/moonrocks/ - Failed downloading http://luafr.org/moonrocks/manifest - /root/.cache/luarocks
/http___luafr.org_moonrocks_/manifest
Warning: Failed searching manifest: Failed fetching manifest for http://luarocks.logiceditor.com/rocks - Failed downloading http://luarocks.logiceditor.com/rocks/manifest -
/root/.cache/luarocks/http___luarocks.logiceditor.com_rocks/manifest
```

"failed to fetch the manifest".. hrm..

Having used Alpine a bit, this type of issue is usually "a package is missing" and resolved by adding some package and/or running some update process.

I first suspect SSL and `ca-certificates`, but that wasn't successful:

```
/ # apk add --update ca-certificates
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/community/x86_64/APKINDEX.tar.gz
(1/1) Installing ca-certificates (20161130-r0)
Executing busybox-1.25.1-r0.trigger
Executing ca-certificates-20161130-r0.trigger
OK: 6 MiB in 17 packages
/ # update-ca-certificates
WARNING: ca-certificates.crt does not contain exactly one certificate or CRL: skipping
/ # luarocks-5.1 install cjson
Warning: Failed searching manifest: Failed fetching manifest for https://luarocks.org - Failed downloading https://luarocks.org/manifest - /root/.cache/luarocks/https___luar
ocks.org/manifest
...
```

I eventually found [this comment](https://github.com/openresty/docker-openresty/issues/23#issuecomment-266235356), which mentions:

> Turns out that luarocks needs `unzip` and `curl` packages. Please add them to `alpine-fat` image, so we can have working `luarocks` by default.

OK, so that should be easy:

```
/ # apk add unzip curl
(1/5) Installing ca-certificates (20161130-r0)
(2/5) Installing libssh2 (1.7.0-r2)
(3/5) Installing libcurl (7.52.1-r2)
(4/5) Installing curl (7.52.1-r2)
(5/5) Installing unzip (6.0-r2)
Executing busybox-1.25.1-r0.trigger
Executing ca-certificates-20161130-r0.trigger
OK: 7 MiB in 21 packages
/ # luarocks-5.1 search cjson

Search results:
===============


Rockspecs and source rocks:
---------------------------

lua-cjson
   2.1.0-1 (rockspec) - https://luarocks.org
...
```

Yay!

### Exploring `package.path`

Every now and again, I run into something like:

```
/ # lua /src/worker.lua
lua: /src/worker.lua:1: module 'cjson' not found:
        no field package.preload['cjson']
        no file './cjson.lua'
        no file '/usr/local/share/lua/5.1/cjson.lua'
        no file '/usr/local/share/lua/5.1/cjson/init.lua'
        no file '/usr/local/lib/lua/5.1/cjson.lua'
        no file '/usr/local/lib/lua/5.1/cjson/init.lua'
        no file '/usr/share/lua/5.1/cjson.lua'
        no file '/usr/share/lua/5.1/cjson/init.lua'
        no file './cjson.so'
        no file '/usr/local/lib/lua/5.1/cjson.so'
        no file '/usr/lib/lua/5.1/cjson.so'
        no file '/usr/local/lib/lua/5.1/loadall.so'
stack traceback:
        [C]: in function 'require'
        /src/worker.lua:1: in main chunk
        [C]: ?
```

Not able to find `cjson`? That seems odd, it's right there:

```
/ # find / -type f -name cjson*
/usr/local/openresty/lualib/cjson.so
```

Hrm, so how do we address this? I had seen a few of these, and I noticed it generally didn't happen with openresty unless I was requesting a package which I had not yet installed (so that made sense). While I'm not familiar with package management in lua, this seems to be related to that being needed when running outside the pre-configured openresty env I have.

Searching for "_lua lib path_", I ended up on http://lua-users.org/wiki/PackagePath, which points out the existence of`package.path`:

>  A schematic representation of that list is kept in the variable `package.path`.  For the above
>  list, that variable contains...

Unfortunately, that wiki doesn't include an example that updates or customizes `package.path`.

http://stackoverflow.com/a/4126565 mentions:

> You can also change `package.path` in Lua before calling `require`.

..so let's explore `package.path` a little:

```lua
/ # /usr/local/openresty/luajit/bin/luajit
LuaJIT 2.1.0-beta2 -- Copyright (C) 2005-2016 Mike Pall. http://luajit.org/
JIT: ON SSE2 SSE3 SSE4.1 fold cse dce fwd dse narrow loop abc sink fuse
>
> print(package.path)
./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta2/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua
```

This looks like a string, let's see if we can add to it:

```lua
> foo = "bar"
> foo += "baz"
stdin:1: '=' expected near '+'
> foo = foo + "baz"
stdin:1: attempt to perform arithmetic on global 'foo' (a string value)
stack traceback:
        stdin:1: in main chunk
        [C]: at 0x7f9ea8351bd0
> foo = foo .. "baz"
> print(foo)
barbaz
```

OK, so use `..` for string concatenation (and `+` requires proper types)

```lua
> package.path = package.path .. ";/usr/local/openresty/lualib/?.lua"
> print(package.path)
./?.lua;/usr/local/openresty/luajit/share/luajit-2.1.0-beta2/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/luajit/share/lua/5.1/?.lua;/usr/local/openresty/luajit/share/lua/5.1/?/init.lua;/usr/local/openresty/lualib/?.lua
```

Let's see if that works in our script..

```
package.path= package.path .. ";/usr/local/openresty/lualib/?.so"
local cjson = require "cjson"
```

(BTW, there are better ways to do this, see http://stackoverflow.com/a/31626271 for some options)

hrm...

```
# /usr/local/openresty/luajit/bin/luajit /src/worker.lua
/usr/local/openresty/luajit/bin/luajit: error loading module 'cjson' from file '/usr/local/openresty/lualib/cjson.so':
        /usr/local/openresty/lualib/cjson.so:1: unexpected symbol near 'char(127)'
stack traceback:
        [C]: at 0x7f7c2a441240
        [C]: in function 'require'
        /src/worker.lua:2: in main chunk
        [C]: at 0x7f7c2a3f7bd0
```

At this point, I'd rather drop back to a "standard/basic lua env" that is not openresty. EG, the openresty env has specifics I don't understand, and using lua outside of nginx isn't working right. There is another way to solve this problem: build a basic lua env.

### Build stand-alone docker image with lua

EG, for many of the previous exercises, we've used the `openresty:alpine` image, but I sometimes want to use lua straight up, without openresty, luajit, or the environment that openresty has setup (if only to confirm what I see is related to the openresty environment). The module/path issues noted above are also a motivation for this.

Let's setup a basic docker image with lua and luarocks, based on `alpine`. We'll add `unzip`,`curl`, `gcc`, and `build-base` for fetching/building modules with `luarocks`:

```Dockerfile
FROM alpine:latest

RUN  apk add --update unzip curl build-base gcc lua5.1 lua5.1-dev luarocks5.1

VOLUME  /src
WORKDIR /src
ENTRYPOINT /bin/sh
```

Here is our `Makefile`, to make this a little easier:

```
build:
        docker build --tag=lua --rm .

run:
        docker run -it --rm -v `pwd`:/src lua

test:
        # Run the following two commands:
        #   make run
        #   luarocks-5.1 install lua-cjson && lua5.1 cjson-test.lua
```

We will mount the current working directory as `/src` in the image, and run our lua from there.

Go to `examples/stand-alone-lua-image` and build it:

```
ᐅ cd examples/stand-alone-lua-image
ᐅ make build
docker build --tag=lua --rm .
Sending build context to Docker daemon 4.096 kB
Step 1 : FROM alpine:latest
 ---> fe3e188d9166
Step 2 : RUN apk add --update unzip curl build-base gcc lua5.1 lua5.1-dev luarocks5.1
 ---> Running in 73bbb2c31559
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.5/community/x86_64/APKINDEX.tar.gz
(1/29) Upgrading musl (1.1.15-r5 -> 1.1.15-r6)
(2/29) Installing binutils-libs (2.27-r0)
(3/29) Installing binutils (2.27-r0)
(4/29) Installing gmp (6.1.1-r0)
(5/29) Installing isl (0.17.1-r0)
(6/29) Installing libgomp (6.2.1-r1)
(7/29) Installing libatomic (6.2.1-r1)
(8/29) Installing pkgconf (1.0.2-r0)
(9/29) Installing libgcc (6.2.1-r1)
(10/29) Installing mpfr3 (3.1.5-r0)
(11/29) Installing mpc1 (1.0.3-r0)
(12/29) Installing libstdc++ (6.2.1-r1)
(13/29) Installing gcc (6.2.1-r1)
(14/29) Installing make (4.2.1-r0)
(15/29) Installing musl-dev (1.1.15-r6)
(16/29) Installing libc-dev (0.7-r1)
(17/29) Installing fortify-headers (0.8-r0)
(18/29) Installing g++ (6.2.1-r1)
(19/29) Installing build-base (0.4-r1)
(20/29) Installing ca-certificates (20161130-r0)
(21/29) Installing libssh2 (1.7.0-r2)
(22/29) Installing libcurl (7.52.1-r2)
(23/29) Installing curl (7.52.1-r2)
(24/29) Upgrading musl-utils (1.1.15-r5 -> 1.1.15-r6)
(25/29) Installing lua5.1-libs (5.1.5-r2)
(26/29) Installing lua5.1 (5.1.5-r2)
(27/29) Installing lua5.1-dev (5.1.5-r2)
(28/29) Installing luarocks5.1 (2.4.2-r0)
(29/29) Installing unzip (6.0-r2)
Executing busybox-1.25.1-r0.trigger
Executing ca-certificates-20161130-r0.trigger
OK: 161 MiB in 38 packages
 ---> 6790dd1671c6
Removing intermediate container 73bbb2c31559
Step 3 : VOLUME /src
 ---> Running in 24a551c29f23
 ---> 61dc8c8fe791
Removing intermediate container 24a551c29f23
Step 4 : WORKDIR /src
 ---> Running in f5d7b97948a7
 ---> 1ac18b1d38f1
Removing intermediate container f5d7b97948a7
Step 5 : ENTRYPOINT /bin/sh
 ---> Running in 1ceba58c9546
 ---> ef633a63546e
Removing intermediate container 1ceba58c9546
Successfully built ef633a63546e
```

Let's test the image with our `cjson` situation above. We have a simple script - `cjson-test.lua` - it will exit 0 if it can import and use the cjson package:

```lua
local cjson = require "cjson"
print(cjson.encode({status = "success!"}))
```

Let's use the `lua` base image we created above, install the `lua-cjson` package, and then run our `cjson-test.lua` script:

```
ᐅ make run
docker run -it --rm -v `pwd`:/src lua
/src #
/src # luarocks-5.1 install lua-cjson
Installing https://luarocks.org/lua-cjson-2.1.0-1.src.rock
gcc -O2 -fPIC -I/usr/include -c lua_cjson.c -o lua_cjson.o
In file included from lua_cjson.c:47:0:
fpconv.h:15:20: warning: inline function 'fpconv_init' declared but never defined
 extern inline void fpconv_init();
                    ^~~~~~~~~~~
gcc -O2 -fPIC -I/usr/include -c strbuf.c -o strbuf.o
gcc -O2 -fPIC -I/usr/include -c fpconv.c -o fpconv.o
gcc -shared -o cjson.so -L/usr/lib lua_cjson.o strbuf.o fpconv.o
No existing manifest. Attempting to rebuild...
lua-cjson 2.1.0-1 is now installed in /usr/local (license: MIT)
```

Awesome, installed the package. Let's run the test:

```
/src # lua5.1 cjson-test.lua
{"status":"success!"}
```

## Exercise 7: basic data processing sink

* Basic
* stand-alone (no openresty or nginx)
* connect to redis
* watch queue for new items
* for each item in the queue, do something with it (print it to stdout for now)
* if there's no work, just sit idle

This exercise is getting further into the unknown, and it might take a few steps before we have a working solution.

### Got stuck iterating over various redis client libraries to find one that would work..

* `resty.redis` (which I used in exercise 6) is not available outside the openresty environment (and I'm not sure how to run lua in that env without nginx - or at least the `ngx` variable if not running in nginx).
* `moon-redis` is a data modeling library
* `redis-lua` appeared to have a dependency on `resty.redis` (at least I believe so)
* `hiredis` appears to work, but is a pile of C that hasn't been updated since 2014, so there's that (but supposedly used in hi-volume production).

### Testing `hiredis`...

Let's test the connection, we'll go to `examples/07-redis-data-sink/tests/` for this. Here is our code:

```lua
local cjson = require "cjson"
local redis  = require "hiredis"
local client, err, err_code = hiredis.connect("127.0.0.1", 6379)
if not client then
  print("failed to connect to redis..")
  print("error: " .. err)
  print("code:  " .. err_code)
  return
end
```

Here's our `Makefile`:

```
build:
        docker build --tag=ping-redis:7 --rm=true .

run:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run -d --name ping-redis  --net host -p 127.0.0.1:8000:8000 ping-redis:7

fail:
        docker run -it --rm --entrypoint /usr/local/openresty/luajit/bin/luajit ping-redis:7 ping.lua

dev:
        docker run -it --rm -v `pwd`:/src ping-redis:7

dev-redis:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run --rm -it --name ping-redis  --net host -v `pwd`:/src ping-redis:7

clean:
        docker stop redis       || true
        docker stop ping-redis  || true
        docker rm   redis       || true
        docker rm   ping-redis  || true
```

Here's our `Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
ADD *.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh
```

Build that image:

```
ᐅ make build
docker build --tag=ping-redis:7 --rm=true .
Sending build context to Docker daemon 4.608 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
 ---> Using cache
 ---> 9f523055586e
Step 3 : ADD *.lua /src/
 ---> 2dd66d628a62
Removing intermediate container d5a31e9154d6
Step 4 : WORKDIR /src/
 ---> Running in 6a2c97caef1c
 ---> 4070a74cbaaa
Removing intermediate container 6a2c97caef1c
Step 5 : ENTRYPOINT /bin/sh
 ---> Running in 7b9f72e426e2
 ---> 101646a10ba3
Removing intermediate container 7b9f72e426e2
Successfully built 101646a10ba3
```

First test, with no redis available:

```
ᐅ make fail
docker run -it --rm --entrypoint /usr/local/openresty/luajit/bin/luajit ping-redis:7 ping.lua
failed to connect to redis..
error: Connection refused
code:  1
```

Test with redis available:

```
ᐅ make run
docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
39980a15a0465e637019bb29c3a531398a3362cf35b9623a29c712e3d8f49208
docker run -it --rm --net host --entrypoint /usr/local/openresty/luajit/bin/luajit ping-redis:7 ping.lua
PONG:
true
```

YAY!

### Let's test some push /// pop /// RPOPLPUSH..

For this test, we'll write another stand-alone script that simulates a few steps in the general workflow the worker goes through when processing a single item on the queue. This will do the following:

* connect to redis
* left push a few values to a list (3 or 4)
* use `RPOPLPUSH` to pop one value from the `enqueued` list, and push that value to a `processing` list
* do something with that value (print it)
* use `LREM` to remove the item from the processing list.
  * this should work fine for basic situations, but would need more thorough testing to guard against race conditions across multiple workers (though it ought to be ok if the keys are unique)

The push/pop workflow looks like:

```
 +------+
 | JSON |
 +--+---+
    |
    |
    V
+--------+
|producer|
+---+----+
    |
    |
    |  LPUSH    +---+---+---+---+    RPOPLPUSH    +---+---+---+---+
    +---------> | d | c | b | a +->-->---+--->--->+ x | . | . |   |
                +---+---+---+---+        |        +---+---+---+---+
                                         |          |
                                         V          V LREM when done
                                     +---+----+
                                     |Consumer|
                                     +--------+
```

Relevant docs for these redis operations:

* [`RPOPLPUSH`](https://redis.io/commands/rpoplpush)
* [`LREM`](https://redis.io/commands/lrem)

Note that it's also worth understanding the difference between `RPOPLPUSH` and `BRPOPLPUSH` (the blocking variant).

The code for our test is simple but a tad verbose:

```lua
local redis  = require "hiredis"
-- return redis client, or fail and exit
connect = function (host)
  local rc, err, err_code = hiredis.connect(host, 6379)
  if not rc then
    print("failed to connect to redis..")
    print("error: " .. err)
    print("code:  " .. err_code)
    os.exit(1)
  else
    return rc
  end
end
-- send a PING to redis and print True/False for PONG as result
ping_pong = function(client)
  print("PONG:")
  print(client:command("PING") == hiredis.status.PONG)
end
-- push a few test keys simulating a writing producer
push_keys = function(client)
  rc:command("LPUSH", "enqueued", "a")
  rc:command("LPUSH", "enqueued", "b")
  rc:command("LPUSH", "enqueued", "c")
  rc:command("LPUSH", "enqueued", "d")
end
-- return the lua table that is the redis list, in full
get_list = function(client, list)
  return client:command("LRANGE", list, 0, -1)
end
-- for the lua table t, print the key/value pairs (one level)
print_table = function(t)
  for k,v in pairs(t) do
    print(k, v)
  end
end
-- wrap redis RPOPLPUSH
rpoplpush = function(q, p)
  return rc:command("RPOPLPUSH", q, p)
end
-- wrap redis LREM
drop = function(tbl, key)
  return rc:command("LREM", tbl, 1, key)
end
--
-- MAIN
rc = connect("127.0.0.1")
ping_pong(rc)
-- push some keys to the q
push_keys(rc)
-- print out those keys
print("LRANGE enqueued:")
q = get_list(rc, "enqueued")
print_table(q)
-- RPOPLPUSH one key over to processing
pop = rpoplpush("enqueued", "processing")
print("pop the queue, now processing: " .. pop)
-- retrieve and print the two lists as they are now..
q = get_list(rc, "enqueued")
print("queue is now:")
print_table(q)
--
p = get_list(rc, "processing")
print("processing is now:")
print_table(p)
-- ok, we're done with the key, let's drop it
print("done with:")
print(pop)
print("drop from processing..")
print(drop("processing", pop))
-- retrieve and print the two lists as they are now..
q = get_list(rc, "enqueued")
print("queue:")
print_table(q)
--
p = get_list(rc, "processing")
print("processing:")
print_table(p)
-- goodbye redis
rc:close()
```

This is our first time defining functions, they are in the form:

```lua
foo = function(args)
  stmt
end
```

Here is our `Makefile`:

```
build:
        docker build --tag=push-pop:7 --rm=true .

run:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run -it --rm --net host --entrypoint /usr/local/openresty/luajit/bin/luajit push-pop:7 queue-test.lua

dev:
        docker run -it --rm -v `pwd`:/src push-pop:7

dev-redis:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run --rm -it --name push-pop  --net host -v `pwd`:/src push-pop:7

clean:
        docker stop redis     || true
        docker stop push-pop  || true
        docker rm   redis     || true
        docker rm   push-pop  || true
```

Here is our `Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
ADD *.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh
```

Let's build the image:

```
ᐅ make build
docker build --tag=push-pop:7 --rm=true .
Sending build context to Docker daemon 18.94 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
 ---> Using cache
 ---> 9f523055586e
Step 3 : ADD *.lua /src/
 ---> ffd368d4359d
Removing intermediate container cd9f8b513598
Step 4 : WORKDIR /src/
 ---> Running in bc6b44a78bcc
 ---> df60616db41a
Removing intermediate container bc6b44a78bcc
Step 5 : ENTRYPOINT /bin/sh
 ---> Running in 5eca9952a6c1
 ---> f57567ee339a
Removing intermediate container 5eca9952a6c1
Successfully built f57567ee339a
```

Run the quick tests:

```
ᐅ make run
docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
f898eff2d7ff61368757992277e58e427d70504eb2f4f128e324bcc8d4255c43
docker run -it --rm --net host --entrypoint /usr/local/openresty/luajit/bin/luajit push-pop:7 queue-test.lua
PONG:
true
LRANGE enqueued:
1       d
2       c
3       b
4       a
pop the queue, now processing: a
queue is now:
1       d
2       c
3       b
processing is now:
1       a
done with:
a
drop from processing..
1
queue:
1       d
2       c
3       b
processing:
```

### OK, Let's get more serious..

We'll need three pieces to this puzzle:

* redis - docker image, easy
* webapp (nginx/openresty) - accepts POST and writes to redis
* worker (stand-alone Lua script) - attempts to pop from queue and process data

The worker's logic would look like:

```
while true
  item = RPOPLPUSH(q, p)
  process(item)
  donedrop(item)
  sleep(delay)
```

To run tests on this stack, we will also want a 4th component, a `producer.lua` that fills redis with some keys for the worker to process.

Having run the simpler tests in this exercise, we can now complete the primary goals  for this exercise:

* connect to redis
* watch the queue
* process an item when one is available (print it)
* site idle while there are no items on the queue
* It should be easy to load new values onto the queue

Let's start with the `Dockerfile`:

````dockerfile
FROM openresty/openresty:alpine-fat

ENV REDIS_HOST 127.0.0.1
RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
ADD *.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh
````

The `Makefile`:

```
build:
        docker build --tag=sink:7 --rm=true .

run:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:7 worker.lua

dev:
        docker run -it --rm --entrypoint /bin/sh -v `pwd`:/src sink:7

dev-redis:
        docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
        docker run --rm -it --name sink --net host --entrypoint /bin/sh -v `pwd`:/src sink:7

clean:
        docker stop redis || true
        docker stop sink  || true
        docker rm   redis || true
        docker rm   sink  || true

logs:
        docker logs -f sink

cat-posts:
        docker exec -it redis redis-cli -c LRANGE enqueued 0 -1

load-redis:
        docker exec sink /usr/local/openresty/luajit/bin/luajit /src/producer.lua

app-shell:
        docker exec -it sink  /bin/sh

redis-shell:
        docker exec -it redis redis-cli
```

Here is our `producer.lua`:

```lua
local cjson = require "cjson"
local redis = require "hiredis"
-- names for our lists in redis
local q     = "enqueued"
-- return redis client, or fail and exit
connect = function (host)
  local rc, err, err_code = hiredis.connect(host, 6379)
  if not rc then
    print("failed to connect to redis..")
    print("error: " .. err)
    print("code:  " .. err_code)
    os.exit(1)
  else
    return rc
  end
end
-- push a key to the queue
enqueue = function(key)
  rc:command("LPUSH", q, key)
end
--
-- MAIN
rc = connect(os.getenv("REDIS_HOST"))
assert(rc)
for l=1, 100000
do
  print("enqueue: " .. l)
  date_fmt = "%m-%d-%Y--%H-%M-%S"
  enqueue(cjson.encode({timestamp = os.date(date_fmt), msg = "hi! this is " .. l}))
  l = l + 1
end
```

..and the `worker.lua`:

```lua
local cjson = require "cjson"
-- install lua-hiredis
local redis = require "hiredis"
-- names for our lists in redis
local q     = "enqueued"
local p     = "processing"
local delay = 0.001
-- return redis client, or fail and exit
connect = function (host)
  local rc, err, err_code = hiredis.connect(host, 6379)
  if not rc then
    print("failed to connect to redis..")
    print("error: " .. err)
    print("code:  " .. err_code)
    os.exit(1)
  else
    return rc
  end
end
-- retrieve work from redis, store it in "processing" table
get_work = function()
  return rc:command("RPOPLPUSH", q, p)
end
-- "do" the work
process = function (i)
  print(i)
end
-- work is done, drop it from the processing table
dondrop = function (i)
  return rc:command("LREM", p, 1, i)
end
-- pause for a moment..
-- could also use socket.sleep(sec) from the "socket" library
sleep = function(t)
  os.execute("sleep " .. tonumber(t))
end
--
-- MAIN
rc = connect(os.getenv("REDIS_HOST"))
assert(rc)
-- loop doing work until you can't
while true do
  item, err, code = get_work(q, p)
  if item.name == "NIL" then
    -- pass
  else
    --print("got item!")
    process(item)
    dondrop(item)
    sleep(delay)
  end
end
rc:close()
```

Let's build the docker image:

```
ᐅ make build
docker build --tag=sink:7 --rm=true .
Sending build context to Docker daemon 69.12 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : ENV REDIS_HOST 127.0.0.1
 ---> Using cache
 ---> de5f965dde03
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
 ---> Using cache
 ---> 7c775cdb7262
Step 4 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
 ---> Using cache
 ---> ae1368fbc83c
Step 5 : ADD *.lua /src/
 ---> df004e1f873f
Removing intermediate container f99ad0182f1e
Step 6 : WORKDIR /src/
 ---> Running in c83514aa60cf
 ---> 532d74acb351
Removing intermediate container c83514aa60cf
Step 7 : ENTRYPOINT /bin/sh
 ---> Running in 779030fb4864
 ---> f487b5262d67
Removing intermediate container 779030fb4864
Successfully built f487b5262d67
```

Run redis and the worker:

```
ᐅ make run
docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
57f9820ed7091761dddfd2547391c6509e4c065d36ef0f2c989ff00fdc4e8950
docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:7 worker.lua
2bf77a4d780c516d6685c5c1ef6c8e5a1b7be9ec07ae7c1d6a8618bd0cccde68
```

We should see them with `docker ps`:

```
ᐅ docker ps
CONTAINER ID  IMAGE        COMMAND                CREATED        STATUS   PORTS NAMES
2bf77a4d780c  sink:7       "/usr/local/openresty" 32 seconds ago Up 32 seconds  sink
57f9820ed709  redis:alpine "docker-entrypoint.sh" 32 seconds ago Up 32 seconds  redis
```

In one shell/terminal, watch the logs..

```
ᐅ make logs
docker logs -f sink
```

Load up redis with a bunch of data (100k keys):

```
ᐅ make load-redis | tail
enqueue: 99991
enqueue: 99992
enqueue: 99993
enqueue: 99994
enqueue: 99995
enqueue: 99996
enqueue: 99997
enqueue: 99998
enqueue: 99999
enqueue: 100000
```

As soon as that starts, you should see log activity from the worker, something like:

```
...
{"timestamp":"03-05-2017--03-06-08","msg":"hi! this is 99995"}
{"timestamp":"03-05-2017--03-06-08","msg":"hi! this is 99996"}
{"timestamp":"03-05-2017--03-06-08","msg":"hi! this is 99997"}
{"timestamp":"03-05-2017--03-06-08","msg":"hi! this is 99998"}
{"timestamp":"03-05-2017--03-06-08","msg":"hi! this is 99999"}
```

## Exercise 8: Restrict based on HTTP method

Let's say you have an endpoint that accepts `GET` and `POST`, how do you ensure you only process requests of those type, and block non-allowed methods as early as possible? The purpose of this exercise is to demonstrate how to inspect and react to the specific HTTP method used to access the URI location. While there are multiple ways to accomplish this directly in `nginx.conf`,  we will use Lua to inspect and take action on these methods.

In short, our filter could look like:

```lua
local http_method = ngx.var.request_method
if http_method == ngx.HTTP_GET then
  local cjson = require "cjson"
  ngx.status = ngx.HTTP_OK
  ngx.say(cjson.encode({method = "GET", status = "allowed"}))
  return ngx.exit(ngx.HTTP_OK)
else
  ngx.status = ngx.HTTP_NOT_ALLOWED
  ngx.say(cjson.encode({method = http_method , status = "denied"}))
  return ngx.exit(ngx.HTTP_NOT_ALLOWED)
end
```

Note.. in testing this, `ngx.HTTP_GET` appears to be `2`, while `ngx.HTTP_POST` is `8`, so I have used this instead:

```lua
local http_method = ngx.var.request_method
if http_method == "GET" then
  local cjson = require "cjson"
  ngx.status = ngx.HTTP_OK
  ngx.say(cjson.encode({method = "GET", status = "allowed"}))
  return ngx.exit(ngx.HTTP_OK)
else
  ngx.status = ngx.HTTP_NOT_ALLOWED
  ngx.say(cjson.encode({method = http_method , status = "denied"}))
  return ngx.exit(ngx.HTTP_NOT_ALLOWED)
end
```

Here is the `Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
```

The `Makefile`:

```
build:
        docker build --tag=app:8 --rm=true ./

run:
        docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:8

dev:
        docker run --rm -it --name app --net host --entrypoint /bin/sh -v `pwd`/app:/src app:8

clean:
        docker stop app || true
        docker rm   app || true

reload:
        docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
        docker exec -it app tail -f /usr/local/openresty/nginx/error.log

test:
        curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/get
        curl -i -H "Content-Type: application/json"                                                  localhost:8000/get
        curl -i -H "Content-Type: application/json"                                                  localhost:8000/post
        curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/post
```

...and the webapp code:

```nginx
worker_processes  1;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location /get {
            content_by_lua '
              local cjson = require "cjson"
              local http_method = ngx.var.request_method
              if http_method == "GET" then
                ngx.status = ngx.HTTP_OK
                ngx.say(cjson.encode({method = "GET", status = "allowed"}))
                return ngx.exit(ngx.HTTP_OK)
              else
                ngx.status = ngx.HTTP_NOT_ALLOWED
                ngx.say(cjson.encode({method = http_method , status = "denied"}))
                return ngx.exit(ngx.HTTP_NOT_ALLOWED)
              end
            ';
        }
        location /post {
            content_by_lua '
              local cjson = require "cjson"
              local http_method = ngx.var.request_method
              if http_method == "POST" then
                ngx.status = ngx.HTTP_OK
                ngx.say(cjson.encode({method = "POST", status = "allowed"}))
                return ngx.exit(ngx.HTTP_OK)
              else
                ngx.status = ngx.HTTP_NOT_ALLOWED
                ngx.say(cjson.encode({method = http_method , status = "denied"}))
                return ngx.exit(ngx.HTTP_NOT_ALLOWED)
              end
            ';
        }
    }
}
```

Build the image:

```
ᐅ make build
docker build --tag=app:8 --rm=true ./
Sending build context to Docker daemon 6.144 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
 ---> Using cache
 ---> 88eaefcb0701
Step 4 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> 0f06fa265a56
Removing intermediate container 17a6406417d9
Successfully built 0f06fa265a56
```

Run the image:

```
ᐅ make run
docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:8
2f52d4449835fe5bc3cfe3881e45c442d742bf1bfbd784d201e1ef3872615a5d
```

Run tests on the webapp:

```
ᐅ make test
curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/get
HTTP/1.1 405 Not Allowed
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 05:22:31 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"denied","method":"POST"}
curl -i -H "Content-Type: application/json"                                                  localhost:8000/get
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 05:22:31 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"allowed","method":"GET"}
curl -i -H "Content-Type: application/json"                                                  localhost:8000/post
HTTP/1.1 405 Not Allowed
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 05:22:31 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"denied","method":"GET"}
curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/post
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 05:22:31 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"allowed","method":"POST"}
```



### Exercise 9: GET retrieve JSON msg from postgres

Before we weave these few components into the actual demo, there is one last component to work out, bulk retrieval for the messages in postgres, dumping the JSON. For a `GET` to `/list`, the app should retrieve the top 100 entries in the `posts` table in postgres.

`cd` to `examples/09-batch-read-from-postgres/` to run and/or see the code for this exercise.

Here is our app code in `nginx.conf`:

```lua
worker_processes  1;
env DB_HOST;
env DB_USER;
env DB_PASS;
env DB_NAME;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location /list {
            content_by_lua '
              local cjson = require "cjson"
              local http_method = ngx.var.request_method
              if http_method == "GET" then
                local pgmoon = require "pgmoon"
                local pg = pgmoon.new({
                  host     = os.getenv("DB_HOST"),
                  port     = "5432",
                  user     = os.getenv("DB_USER"),
                  password = os.getenv("DB_PASS"),
                  database = os.getenv("DB_NAME")
                })
                assert(pg:connect())
                local get, post, files = require "resty.reqargs"()
                top = pg:query("SELECT data FROM posts ORDER BY id DESC LIMIT 100;")
                pg:keepalive()
                pg = nil
                ngx.status = ngx.HTTP_OK
                ngx.say(cjson.encode({ msg = top }))
                return ngx.exit(ngx.HTTP_OK)
              else
                ngx.status = ngx.HTTP_NOT_ALLOWED
                ngx.say(cjson.encode({method = http_method , status = "denied"}))
                return ngx.exit(ngx.HTTP_NOT_ALLOWED)
              end
            ';
        }
    }
}
```

The `producer.lua`:

```lua
local cjson = require "cjson"
local pgmoon = require "pgmoon"
local pg = pgmoon.new({
  host     = os.getenv("DB_HOST"),
  port     = "5432",
  user     = os.getenv("DB_USER"),
  password = os.getenv("DB_PASS"),
  database = os.getenv("DB_NAME")
})
assert(pg:connect())
local encode_json = require("pgmoon.json").encode_json

write = function(data)
  assert(pg:query("INSERT INTO posts (data) VALUES(" .. encode_json(data) .. ");"))
  print(data)
end

--
-- MAIN
for l=1, 500
do
  print("enqueue: " .. l)
  date_fmt = "%m-%d-%Y--%H-%M-%S"
  write(cjson.encode({timestamp = os.date(date_fmt), msg = "hi! this is " .. l}))
  l = l + 1
end
```

The `Makefile`:

```
build:
        docker build --tag=db:9  --rm=true ./db
        docker build --tag=app:9 --rm=true ./app

run:
        docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db:9
        docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:9

dev:
        docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db:9
        docker run -d --name app --net host -p 127.0.0.1:8000:8000 -v `pwd`/app/producer.lua:/src/producer.lua -v `pwd`/app/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf app:9

shell:
        docker exec -it app /bin/sh

clean:
        docker stop db  || true
        docker stop app || true
        docker rm   db  || true
        docker rm   app || true

reload:
        docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
        docker exec -it app tail -f /usr/local/openresty/nginx/error.log

cat-posts:
        docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'

load-pg:
        docker exec app /usr/local/openresty/luajit/bin/luajit /src/producer.lua

test:
        curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/list
        curl -i -H "Content-Type: application/json" localhost:8000/list
```

The app's `Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
ADD producer.lua /src/
ENV DB_HOST 127.0.0.1
ENV DB_USER postgres
ENV DB_PASS password
ENV DB_NAME lua-app
```

The db's `Dockerfile`:

```Dockerfile
FROM postgres:alpine
ENV  POSTGRES_PASSWORD password
ENV  POSTGRES_DB       lua-app
ADD  init.sql /docker-entrypoint-initdb.d/
```

...and the db's `init.sql`:

```
CREATE TABLE posts (ID SERIAL PRIMARY KEY, data JSONB);
```

Build the Docker images:

```
ᐅ make build
docker build --tag=db:9  --rm=true ./db
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM postgres:alpine
 ---> f0476a087b97
Step 2 : ENV POSTGRES_PASSWORD password
 ---> Using cache
 ---> 30d766415bf6
Step 3 : ENV POSTGRES_DB lua-app
 ---> Using cache
 ---> 449a34987810
Step 4 : ADD init.sql /docker-entrypoint-initdb.d/
 ---> Using cache
 ---> 7ac365dda47a
Successfully built 7ac365dda47a
docker build --tag=app:9 --rm=true ./app
Sending build context to Docker daemon 18.43 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
 ---> Using cache
 ---> effd23d59e55
Step 4 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Using cache
 ---> 0cde38c767ed
Step 5 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
 ---> Using cache
 ---> e36fd7404d14
Step 6 : RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
 ---> Using cache
 ---> c637b4563598
Step 7 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> Using cache
 ---> 9cdebc902eb9
Step 8 : ADD producer.lua /src/
 ---> Using cache
 ---> bed09e7cc06e
Step 9 : ENV DB_HOST 127.0.0.1
 ---> Using cache
 ---> c8bd96c15c01
Step 10 : ENV DB_USER postgres
 ---> Using cache
 ---> bab0419316af
Step 11 : ENV DB_PASS password
 ---> Using cache
 ---> 6260be3616d9
Step 12 : ENV DB_NAME lua-app
 ---> Using cache
 ---> 806f38e79387
Successfully built 806f38e79387
```

Run the stack:

```
ᐅ make run
docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db:9
7ba8470ae9b3d42007831c957d7e075bcfa3d598ce0f4107e41a1d467023d119
docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:9
3349b9bb44acbf6dbd456d5e66048072708e8a82f1a30e4a9e43bf464ade0416
```

Load up the database with some posts:

```
ᐅ make load-pg
...
enqueue: 497
{"timestamp":"03-05-2017--06-07-02","msg":"hi! this is 497"}
enqueue: 498
{"timestamp":"03-05-2017--06-07-02","msg":"hi! this is 498"}
enqueue: 499
{"timestamp":"03-05-2017--06-07-02","msg":"hi! this is 499"}
enqueue: 500
{"timestamp":"03-05-2017--06-07-02","msg":"hi! this is 500"}
```

Test query!

```
ᐅ make test | less
Date: Sun, 05 Mar 2017 06:07:51 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"denied","method":"POST"}
curl -i -H "Content-Type: application/json" localhost:8000/list
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
HTTP/1.1 200 OK    0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 06:07:51 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 500\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 499\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 498\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 497\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 496\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 495\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 494\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 493\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 492\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 491\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 490\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 489\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 488\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 487\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 486\"}"},{"data":"{\"timestamp\":\"03-05-2017--06-07-02\",\"msg\":\"hi! this is 485\"}"}
...
```

OK, I think we're ready to put together a demo for the original task!

---

Time Tracking: since last check: 8 hours;   total: 15 hours

---

## The Real Deal

By now, we've covered the majority of the details for each component, let's tie them all together into a cohesive demo. At this point, our stack will look like:

* nginx API server
  * accepts POST with arbitrary JSON, writes that JSON to a queue on redis
    * responds with a confirmation the msg was received and queued, and an echo of the message
  * responds to GET with the last 100 messages posted
* postgres database
* redis
* worker instances
  * poll redis for items on the queue
  * for each item found on the queue, process the item (write it to postgres)
  * run multiple instances

See the `diagram.md` for a visual representation of the components summarized above.

### Makefile

Here is our `Makefile`, rather substantial:

```
build:
	docker build --tag=db:demo   --rm=true ./db
	docker build --tag=app:demo  --rm=true ./app
	docker build --tag=sink:demo --rm=true ./sink

run:
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 app:demo
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

dev:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -v `pwd`/app/producer.lua:/src/producer.lua -v `pwd`/app/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf app:demo

shell-app:
	docker exec -it app /bin/sh

shell-sink:
	docker exec -it sink /bin/sh

shell-redis:
	docker exec -it redis redis-cli

clean:
	docker stop db     || true
	docker stop app    || true
	docker stop sink   || true
	docker stop redis  || true
	docker rm   db     || true
	docker rm   app    || true
	docker rm   sink   || true
	docker rm   redis  || true

reload:
	docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs-app:
	docker exec -it app tail -f /usr/local/openresty/nginx/error.log

cat-posts:
	docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'

cat-queue:
	docker exec -it redis redis-cli -c LRANGE enqueued 0 -1

post-msgs:
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","password":"xyz"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 2, "username":"foo","password":"foo"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 3, "username":"bar","password":"bar"}' localhost:8000/

curl-msgs:
	curl -i -H "Content-Type: application/json" localhost:8000/list
```

### Openresty App

`Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
ENV REDIS_HOST 127.0.0.1
ENV DB_HOST    127.0.0.1
ENV DB_USER    postgres
ENV DB_PASS    password
ENV DB_NAME    lua-app
```

`nginx.conf`:

```nginx
worker_processes  1;                                                                                                                                                 [26/376]
env DB_HOST;
env DB_USER;
env DB_PASS;
env DB_NAME;
env REDIS_HOST;
error_log error.log;
events {
    worker_connections 1024;
}
http {
    server {
        listen        8000;
        charset       utf-8;
        charset_types application/json;
        default_type  application/json;
        location / {
            content_by_lua '
              local cjson = require "cjson"
              local http_method = ngx.var.request_method
              if http_method == "POST" then
                local redis = require "resty.redis"
                local r     = redis:new()
                local ok, err = r:connect(os.getenv("REDIS_HOST"), 6379)
                if not ok then
                  emsg = "failed to connect to queue: "
                  ngx.say(cjson.encode({status = "error", msg = emsg .. err}))
                  return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
                end
                local get, post, files = require "resty.reqargs"()
                assert(r:lpush("enqueued", cjson.encode(post)))
                r = nil
                ngx.status = ngx.HTTP_OK
                ngx.say(cjson.encode({status = "saved", msg=post}))
                return ngx.exit(ngx.HTTP_OK)
              else
                ngx.status = ngx.HTTP_NOT_ALLOWED
                ngx.say(cjson.encode({method = http_method , status = "denied"}))
                return ngx.exit(ngx.HTTP_NOT_ALLOWED)
              end
            ';
        }
        location /list {
            content_by_lua '
              local cjson = require "cjson"
              local http_method = ngx.var.request_method
              if http_method == "GET" then
                local pgmoon = require "pgmoon"
                local pg = pgmoon.new({
                  host     = os.getenv("DB_HOST"),
                  port     = "5432",
                  user     = os.getenv("DB_USER"),
                  password = os.getenv("DB_PASS"),
                  database = os.getenv("DB_NAME")
                })
                assert(pg:connect())
                local get, post, files = require "resty.reqargs"()
                top = pg:query("SELECT data FROM posts ORDER BY id DESC LIMIT 10;")
                pg:keepalive()
                pg = nil
                ngx.status = ngx.HTTP_OK
                ngx.say(cjson.encode({ msg = top }))
                return ngx.exit(ngx.HTTP_OK)
              else
                ngx.status = ngx.HTTP_NOT_ALLOWED
                ngx.say(cjson.encode({method = http_method , status = "denied"}))
                return ngx.exit(ngx.HTTP_NOT_ALLOWED)
              end
            ';
        }

    }
}
```

### Database

`Dockerfile`:

```Dockerfile
FROM postgres:alpine
ENV  POSTGRES_PASSWORD password
ENV  POSTGRES_DB       lua-app
ADD  init.sql /docker-entrypoint-initdb.d/
```

`init.sql` :

```sql
CREATE TABLE posts (ID SERIAL PRIMARY KEY, data JSONB);
```

### Data Processing Sink

`Dockerfile`:

```Dockerfile
FROM openresty/openresty:alpine-fat

ENV REDIS_HOST 127.0.0.1
ENV DB_HOST    127.0.0.1
ENV DB_USER    postgres
ENV DB_PASS    password
ENV DB_NAME    lua-app
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
ADD worker.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh
```

`worker.lua`:

```lua
local cjson  = require "cjson"
local redis  = require "hiredis"
local pgmoon = require "pgmoon"
local pg = pgmoon.new({
  host     = os.getenv("DB_HOST"),
  port     = "5432",
  user     = os.getenv("DB_USER"),
  password = os.getenv("DB_PASS"),
  database = os.getenv("DB_NAME")
})
assert(pg:connect())
local encode_json = require("pgmoon.json").encode_json

-- names for our lists in redis
local q     = "enqueued"
local p     = "processing"
-- length of time (seconds) to sleep
local delay = 0.001

-- return redis client, or fail and exit
credis = function (host)
  local rc, err, err_code = hiredis.connect(host, 6379)
  if not rc then
    print("failed to connect to redis..")
    print("error: " .. err)
    print("code:  " .. err_code)
    os.exit(1)
  else
    return rc
  end
end
-- retrieve work from redis, store it in "processing" table
get_work = function()
  return rc:command("RPOPLPUSH", q, p)
end
-- write data to postgres
write_post = function(data)
  assert(pg:query("INSERT INTO posts (data) VALUES(" .. encode_json(data) .. ");"))
end
-- "do" the work
process = function (i)
  write_post(i)
  print(i)
end
-- work is done, drop it from the processing table
dondrop = function (i)
  return rc:command("LREM", p, 1, i)
end
-- pause for a moment..
-- could also use socket.sleep(sec) from the "socket" library
sleep = function(t)
  os.execute("sleep " .. tonumber(t))
end
--
-- MAIN
rc = credis(os.getenv("REDIS_HOST"))
assert(rc)
-- loop doing work until you can't
while true do
  item, err, code = get_work(q, p)
  if item.name == "NIL" then
    -- pass
  else
    --print("got item!")
    process(item)
    dondrop(item)
  end
  sleep(delay)
end

rc:close()
```

### Make the Images

```
ᐅ make build
docker build --tag=db:demo   --rm=true ./db
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM postgres:alpine
 ---> f0476a087b97
Step 2 : ENV POSTGRES_PASSWORD password
 ---> Using cache
 ---> 30d766415bf6
Step 3 : ENV POSTGRES_DB lua-app
 ---> Using cache
 ---> 449a34987810
Step 4 : ADD init.sql /docker-entrypoint-initdb.d/
 ---> Using cache
 ---> 7ac365dda47a
Successfully built 7ac365dda47a
docker build --tag=app:demo  --rm=true ./app
Sending build context to Docker daemon 18.43 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : EXPOSE 8000
 ---> Using cache
 ---> 35a8c6e42825
Step 3 : RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
 ---> Using cache
 ---> effd23d59e55
Step 4 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
 ---> Using cache
 ---> 0cde38c767ed
Step 5 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
 ---> Using cache
 ---> e36fd7404d14
Step 6 : RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
 ---> Using cache
 ---> c637b4563598
Step 7 : ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
 ---> Using cache
 ---> bc33cf10bf01
Step 8 : ENV REDIS_HOST 127.0.0.1
 ---> Using cache
 ---> 9f78043fdfc7
Step 9 : ENV DB_HOST 127.0.0.1
 ---> Using cache
 ---> c0e0abcf87d5
Step 10 : ENV DB_USER postgres
 ---> Using cache
 ---> f2f16dfddb1f
Step 11 : ENV DB_PASS password
 ---> Using cache
 ---> 7e0b6d86ae27
Step 12 : ENV DB_NAME lua-app
 ---> Using cache
 ---> b0a48a3d9595
Successfully built b0a48a3d9595
docker build --tag=sink:demo --rm=true ./sink
Sending build context to Docker daemon 4.608 kB
Step 1 : FROM openresty/openresty:alpine-fat
 ---> 366babf2b04d
Step 2 : ENV REDIS_HOST 127.0.0.1
 ---> Using cache
 ---> de5f965dde03
Step 3 : ENV DB_HOST 127.0.0.1
 ---> Using cache
 ---> b06582dae81d
Step 4 : ENV DB_USER postgres
 ---> Using cache
 ---> f3df1ddede03
Step 5 : ENV DB_PASS password
 ---> Using cache
 ---> 402db0ba86ba
Step 6 : ENV DB_NAME lua-app
 ---> Using cache
 ---> 030fc5a44f2e
Step 7 : RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
 ---> Using cache
 ---> f8423c4e9542
Step 8 : RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
 ---> Using cache
 ---> d2e0bec18540
Step 9 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
 ---> Using cache
 ---> 64d42d338134
Step 10 : RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
 ---> Using cache
 ---> 899c82d7d9dc
Step 11 : ADD worker.lua /src/
 ---> Using cache
 ---> e08cab28d016
Step 12 : WORKDIR /src/
 ---> Using cache
 ---> d46f7aee15f9
Step 13 : ENTRYPOINT /bin/sh
 ---> Using cache
 ---> f461ed471c63
Successfully built f461ed471c63
docker build --tag=load:demo --rm=true ./load
Sending build context to Docker daemon 15.87 kB
Step 1 : FROM openresty/openresty:alpine
 ---> 984d503b1bd8
Step 2 : ADD load-test.lua /src/
 ---> ad623a0dfb04
Removing intermediate container 21a2b3186d98
Step 3 : WORKDIR /src/
 ---> Running in 715d14831bd5
 ---> c709f22bdc16
Removing intermediate container 715d14831bd5
Step 4 : ENTRYPOINT /bin/sh
 ---> Running in 23f3389007ba
 ---> ecf7b4f08462
Removing intermediate container 23f3389007ba
Successfully built ecf7b4f08462
```

### Run the Demo!

Start 'em up..

```
ᐅ make run
docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
9141dc3fb9788d73be7971dd44a3d140306695914b5422191f5e9de2f42c7f01
docker run -d --name app   --net host -p 127.0.0.1:8000:8000 app:demo
46cde00714668131e32fbcebc4afb417415ef3437fa5bd669c536bc21ba03a11
docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
139def3c153a845d8d3728e6c7de167ed7ab0a6045a32b72d84cd431e3487e53
docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua
c3ad3e737997437ec82d6b2899d8746d1de1a9cef72fdc7b1ad63395e8c4774f
```

Wait, there should be 4!

```
ᐅ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
139def3c153a        redis:alpine        "docker-entrypoint.sh"   11 seconds ago      Up 10 seconds                           redis
46cde0071466        app:demo            "/usr/local/openresty"   11 seconds ago      Up 10 seconds                           app
9141dc3fb978        db:demo             "docker-entrypoint.sh"   12 seconds ago      Up 11 seconds                           db
```

...when the `sink` starts up before postgres is available, the `sink` fails hard. But, interestingly, this is helpful for stepping through the demo. Let's leave the `sink` offline for a moment.

Let's load up the queue with a few messages:

```
ᐅ make post-msgs
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","password":"xyz"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 07:41:15 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"xyz","username":"xyz","id":1}}
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 2, "username":"foo","password":"foo"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 07:41:15 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"foo","username":"foo","id":2}}
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 3, "username":"bar","password":"bar"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 07:41:15 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"bar","username":"bar","id":3}}
```

The `sink` is offline, so requesting the list of lastest posts will return empty:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 07:44:20 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":{}}
```

...and the `posts` table in the database would be empty:

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id | data
----+------
(0 rows)
```

But the messages should be in the queue..

```
ᐅ make cat-queue
docker exec -it redis redis-cli -c LRANGE enqueued 0 -1
1) "{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"
2) "{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"
3) "{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"
```

Let's restart the sink and get those messages moved:

```
ᐅ make rerun-sink
docker rm sink
sink
docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua
188d6516936f974c2a96da9b25d2182bb7390d79b978562f109045a1732cca5a
```

Anything still in the queue?

```
ᐅ make cat-queue
docker exec -it redis redis-cli -c LRANGE enqueued 0 -1
(empty list or set)
```

Anything in the database?

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id |                          data
----+--------------------------------------------------------
  1 | "{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"
  2 | "{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"
  3 | "{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"
(3 rows)
```

OK, let's request them through the API:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 05 Mar 2017 07:48:12 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"},{"data":"{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"},{"data":"{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"}]}
```

can also view thru `jq`:

```
ᐅ make curl-msgs | tail -n 1 | jq .
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   202    0   202    0     0  24363      0 --:--:-- --:--:-- --:--:-- 25250
{
  "msg": [
    {
      "data": "{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"
    },
    {
      "data": "{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"
    },
    {
      "data": "{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"
    }
  ]
}
```



------

Time Tracking: since last check: 2 hours;   total: 17 hours

------

OK, we've gotten a rough cut of the demo in place. We can demonstrate the system is functional in a basic sense, at least with a few requests. Let's take this a step further and see what we can put in place for running load tests.

## Run a Load Test!

Let's put in place a super basic stress test that submits a whole bunch of requests, keep it configurable (in minimal and reasonable ways), and see how the stack holds up to 100k, 500k or even 1M requests.



---

Time Tracking: since last check: 1.5 hours;   total: 18.5 hours

---

## How about some Stats and Metrics?!

Hell, if we're going to send in 1M requests to stress test the system, why not put in place some basic stats and metrics? Prometheus and Grafana to the rescue!

#### The components

* [Prometheus]() - [docker]() - collect, store, and query metrics
* [Grafana]() - [docker]() - display metrics queried from prometheus, build and view dashboards
* A collection of exporters for Prometheus to scrape:
  * [nginx-exporter](https://github.com/discordianfish/nginx_exporter) - [docker](https://hub.docker.com/r/fish/nginx-exporter/)
  * [redis-exporter](https://github.com/oliver006/redis_exporter) - [docker]()
  * [postgres-exporter](https://github.com/wrouesnel/postgres_exporter) - `wrouesnel/postgres_exporter` (docker image)
* [Nginx (lua) Stats Module](https://github.com/knyar/nginx-lua-prometheus) - setup stats reporting for nginx, scrable by Prometheus
* Grafana Dashboards:
  * [nginx](https://grafana.net/dashboards/462)
  * [redis](https://grafana.net/dashboards/763)

#### Tasks

* update `Makefile` with new target `run-stats`, with various `docker run ...` for each of the components
* figure out config bits to add the lua/nginx exporter as a separate server block
  * add a `prometheus.conf` and `include` in `nginx.conf`
* figure out how to include the `nginx-lua-prometheus` module into the app server
  * update the app's `Dockerfile`
* config for prometheus (source + configure where, what and how often to scrape those sources)
* bonus: add data volumes so metrics in prometheus and dashboards in grafana persist until removed by the admin (auto-load grafana dashboards and configure prometheus data source)
* add comments to the `Makefile` - it's got so many targets!
* ensure each of the exporters can reach their target service
* ensure prometheus is collecting stats/metrics from the exporters
* import dashboards and confirm querying promtheus works, and dashboards look good
* map out what should go together in a dashboard for _this_ demo, and create that dashboard
* update docs



### Nginx Lua Stats Export for Prometheus

While there is [this option]().. I am going to make an attempt to use [this lua module](). Lucky us, this is pretty new, but it's looking better/more powerful, and easier to integrate than the existing option.

First, is this lua module available in lua's package manager?

```
ᐅ make shell-loadt
docker run --rm -it --net host -v `pwd`/load/load-test.lua:/src/load-test.lua --entrypoint /bin/sh load:demo
/src # /usr/local/openresty/luajit/bin/luarocks search nginx-lua-prometheus

Search results:
===============


Rockspecs and source rocks:
---------------------------

nginx-lua-prometheus
   0.1-20170303 (rockspec) - https://luarocks.org
   0.1-20170303 (src) - https://luarocks.org
   0.1-2 (rockspec) - https://luarocks.org

/src # exit
```

YES! `nginx-lua-prometheus` it is, no need to worry about getting the source into the right place in the docker image.

### Debug module import

The docs have an error, and I had to figure out how to get the `nginx-lua-prometheus` module working with nginx. The code from the README has the import as `require 'prometheus'`, but I needed `require 'nginx.prometheus'`. The error helped:

```
nginx: [error] init_by_lua error: init_by_lua:2: module 'prometheus' not found:
        no field package.preload['prometheus']
        no file '/usr/local/openresty/site/lualib/prometheus.lua'
        no file '/usr/local/openresty/site/lualib/prometheus/init.lua'
        no file '/usr/local/openresty/lualib/prometheus.lua'
        no file '/usr/local/openresty/lualib/prometheus/init.lua'

        no file './prometheus.lua'
        no file '/usr/local/openresty/luajit/share/luajit-2.1.0-beta2/prometheus.lua'
        no file '/usr/local/share/lua/5.1/prometheus.lua'
        no file '/usr/local/share/lua/5.1/prometheus/init.lua'
                 /usr/local/openresty/luajit/share/lua/5.1/nginx/prometheus.lua
        no file '/usr/local/openresty/luajit/share/lua/5.1/prometheus.lua'
        no file '/usr/local/openresty/luajit/share/lua/5.1/prometheus/init.lua'
        no file '/usr/local/openresty/site/lualib/prometheus.so'
        no file '/usr/local/openresty/lualib/prometheus.so'
        no file './prometheus.so'
        no file '/usr/local/lib/lua/5.1/prometheus.so'
        no file '/usr/local/openresty/luajit/lib/lua/5.1/prometheus.so'
        no file '/usr/local/lib/lua/5.1/loadall.so'
stack traceback:
        [C]: in function 'require'
        init_by_lua:2: in main chunk
```

If this error says "can't find the file", the question is then: "where is the file?":

```
ᐅ docker run -it --entrypoint /bin/sh app:demo
/ # find /usr/local/openresty/ -type f -name prometheus*
/usr/local/openresty/luajit/share/lua/5.1/nginx/prometheus.lua
```

So nginx needs to find `/usr/local/openresty/luajit/share/lua/5.1/nginx/prometheus.lua`..

```
        no file '/usr/local/share/lua/5.1/prometheus.lua'
        no file '/usr/local/share/lua/5.1/prometheus/init.lua'
```

are the two closest, and I noticed the `require` referenced `prometheus` and not `nginx.prometheus`, so I updated the require to: `require 'nginx.prometheus'`.

#### Add an HTTP endpoint for service stats

We add a `prom.conf` where we define a new `server` block for the stats endpoint:

```nginx
lua_shared_dict prometheus_metrics 10M;
init_by_lua '
  prometheus = require("nginx.prometheus").init("prometheus_metrics")
  metric_requests = prometheus:counter(
    "nginx_http_requests_total", "Number of HTTP requests", {"host", "status"})
  metric_latency = prometheus:histogram(
    "nginx_http_request_duration_seconds", "HTTP request latency", {"host"})
  metric_connections = prometheus:gauge(
    "nginx_http_connections", "Number of HTTP connections", {"state"})
';
log_by_lua '
  local host = ngx.var.host:gsub("^www.", "")
  metric_requests:inc(1, {host, ngx.var.status})
  metric_latency:observe(ngx.now() - ngx.req.start_time(), {host})
';
# define a server block to host our metrics endpoint for prometheus to scrape
server {
  listen 9145;
  allow 127.0.0.1;
  deny all;
  location /metrics {
    content_by_lua '
      metric_connections:set(ngx.var.connections_reading, {"reading"})
      metric_connections:set(ngx.var.connections_waiting, {"waiting"})
      metric_connections:set(ngx.var.connections_writing, {"writing"})
      prometheus:collect()
    ';
  }
}
```

This is more or less straight from the module's README, nothing fancy.

We tweak the `nginx.conf` to `include` this new config:

```nginx
http {
    # the config to publish stats/metrics for prometheus to scrape
    include prom.conf;
    ...
}
```

Lua now serves up the stats for Prometheus to scrape.

#### Update the Webapp's `Dockerfile`:

There are two changes:

* install the `nginx-lua-prometheus` package
* add the Nginx config for the stats endpoint

Translated:

```Dockerfile
# install `nginx-lua-prometheus` module/package to use in nginx
RUN /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus
```

```Dockerfile
# nginx config to publish stats/metrics for prometheus to scrape
ADD prom.conf  /usr/local/openresty/nginx/conf/prom.conf
```

The complete `Dockerfile` looks like:

```Dockerfile
FROM openresty/openresty:alpine-fat

EXPOSE 8000
# install package dependencies for our lua webapp
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus
# nginx config for/with lua webapp
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
# nginx config to publish stats/metrics for prometheus to scrape
ADD prom.conf  /usr/local/openresty/nginx/conf/prom.conf
ENV REDIS_HOST 127.0.0.1
ENV DB_HOST    127.0.0.1
ENV DB_USER    postgres
ENV DB_PASS    password
ENV DB_NAME    lua-app
```

### Update the `Makefile`

To make this all work, we need to add a few things to our stack:

- run a stats exporters (for redis, postgres)
- run prometheus
- config for prometheus
- run grafana
- directories for prometheus and grafana to write to, to provide data persistence

Here is the updated `Makefile` with these components:

```
MAX ?= 1000
PG_URL = "postgresql://postgres:password@127.0.0.1:5432/lua-app?sslmode=disable"
PROM_CONF = "/etc/prometheus/prometheus.yml"
PROM_DATA = "/prometheus"
PROM_LOCAL= "stats/data/prometheus"
GRAF_DATA = "/var/lib/grafana"
GRAF_LOCAL= "stats/data/grafana"

build:
	docker build --tag=db:demo    --rm=true ./db
	docker build --tag=app:demo   --rm=true ./app
	docker build --tag=sink:demo  --rm=true ./sink
	docker build --tag=load:demo  --rm=true ./load

run-stats:
	docker run -d --name nexp  --net host -p 127.0.0.1:9113:9113 fish/nginx-exporter -nginx.scrape_uri=http://127.0.0.0.8000/stats
	docker run -d --name rexp  --net host -p 127.0.0.1:9121:9121 oliver006/redis_exporter -redis.addr=127.0.0.1:6379
	docker run -d --name pexp  --net host -p 127.0.0.1:9187:9187 -e DATA_SOURCE_NAME=$(PG_URL) wrouesnel/postgres_exporter
	docker run -d --name prom  --net host -p 127.0.0.1:9090:9090 -v `pwd`/prometheus.yml:$(PROM_CONF) -v `pwd`/$(PROM_LOCAL):$(PROM_DATA) prom/prometheus
	docker run -d --name graf  --net host -p 127.0.0.1:3000:3000 -v `pwd`/$(GRAF_LOCAL):$(GRAF_DATA) grafana/grafana

run:
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 app:demo
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

dev:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 -v `pwd`/app/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf app:demo
	docker run -d --name sink  --net host -v `pwd`/sink/worker.lua:/src/ --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

load-test:
	docker run -it --net host --entrypoint /usr/local/openresty/luajit/bin/luajit load:demo batch-posts.lua --limit $(MAX)

shell-app:
	docker exec -it app /bin/sh

shell-sink:
	docker exec -it sink /bin/sh

shell-redis:
	docker exec -it redis redis-cli

shell-loadt:
	docker run --rm -it --net host -v `pwd`/load/load-test.lua:/src/load-test.lua --entrypoint /bin/sh load:demo

clean:
	docker stop db     || true
	docker stop app    || true
	docker stop sink   || true
	docker stop redis  || true
	docker rm   db     || true
	docker rm   app    || true
	docker rm   sink   || true
	docker rm   redis  || true

clean-stats:
	docker stop graf   || true
	docker stop prom   || true
	docker stop nexp   || true
	docker stop rexp   || true
	docker stop pexp   || true
	docker rm   graf   || true
	docker rm   prom   || true
	docker rm   nexp   || true
	docker rm   rexp   || true
	docker rm   pexp   || true

rmrf-stats:
	rm -rf stats/data/grafana/*
	rm -rf stats/data/prometheus/*

reload:
	docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs-app:
	docker exec -it app tail -f /usr/local/openresty/nginx/error.log

count-posts:
	docker exec -it db psql -U postgres -d lua-app -c 'SELECT COUNT(*) FROM posts;'

cat-posts:
	docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'

count-queue:
	docker exec -it redis redis-cli -c LLEN enqueued
	docker exec -it redis redis-cli -c LLEN processing

cat-queue:
	docker exec -it redis redis-cli -c LRANGE enqueued 0 -1

post-msgs:
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","password":"xyz"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 2, "username":"foo","password":"foo"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 3, "username":"bar","password":"bar"}' localhost:8000/

curl-msgs:
	curl -i -H "Content-Type: application/json" localhost:8000/list

rerun-sink:
	docker rm sink
	docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

add-sinks:
	docker run -d --name sink1  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua
	docker run -d --name sink2  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

rm-sinks:
	docker stop sink1 || true
	docker stop sink2 || true
	docker rm   sink1 || true
	docker rm   sink2 || true
```

#### Prometheus Config

The `Makefile` above runs the exporters on specfic ports, and we need to tell Prometheus how and when to scrape those to collect metrics. Here is our config for Prometheus:

```
global:
  scrape_interval:     15s
  evaluation_interval: 30s
  # scrape_timeout is set to the global default (10s).

scrape_configs:
- job_name: prometheus

  honor_labels: true
  # scrape_interval is defined by the configured global (15s).
  # scrape_timeout is defined by the global default (10s).

  # metrics_path defaults to '/metrics'
  # scheme defaults to 'http'.

  static_configs:
  # - targets: ['localhost:9090', 'localhost:9191']
    - targets: ['localhost:9090']
      labels:
        service: prometheus


- job_name: redis_exporter
  static_configs:
    - targets: ['127.0.0.1:9121']
      labels:
        service: redis

- job_name: postgres_exporter
  static_configs:
    - targets: ['127.0.0.1:9187']
      labels:
        service: postgres

- job_name: nginx_exporter
  static_configs:
    - targets: ['127.0.0.1:9145']
      labels:
        service: nginx
        role: lua-app
```

After the stats stack is running, there are a few additional steps:

- grafana reading from prometheus
- imported dashboards for grafana - stick these URLs into grafana:
  - [nginx](https://grafana.net/dashboards/462)
  - [redis](https://grafana.net/dashboards/763)
  - [postgres](https://grafana.net/dashboards/455)
- see stats when running the benchmarks



------

Time Tracking: since last check: 5 hours;   total: 23.5 hours

------



### Where to go from here?

* build a dashboard for postgres/redis/nginx stats all in one place (those stats relevant to the demo)
* worker could push stats to prometheus' push-gateway

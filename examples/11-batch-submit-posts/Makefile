MAX ?= 1000

build:
	docker build --tag=load:11 --rm=true .

run:
	docker run --rm -it --net host --entrypoint /usr/local/openresty/luajit/bin/luajit load:11 batch-posts.lua --limit $(MAX)

dev:
	docker run --rm -it --net host -v `pwd`/batch-posts.lua:/src/batch-posts.lua --entrypoint /usr/local/openresty/luajit/bin/luajit load:11 batch-posts.lua --list

shell:
	docker run --rm -it --net host -v `pwd`/batch-posts.lua:/src/batch-posts.lua --entrypoint /bin/sh load:11

help:
	docker run --rm -it --entrypoint /usr/local/openresty/luajit/bin/luajit load:11 batch-posts.lua --help

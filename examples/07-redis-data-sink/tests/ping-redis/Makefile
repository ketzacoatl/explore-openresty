build:
	docker build --tag=ping-redis:7 --rm=true .

# add "-v `pwd`:/usr/local/openresty/nginx/conf/" to the app for local dev
run:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -it --rm --net host --entrypoint /usr/local/openresty/luajit/bin/luajit ping-redis:7 ping.lua

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

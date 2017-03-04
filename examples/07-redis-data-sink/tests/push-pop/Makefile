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

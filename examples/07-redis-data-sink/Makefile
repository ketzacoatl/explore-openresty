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

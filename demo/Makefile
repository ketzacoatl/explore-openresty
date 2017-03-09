MAX ?= 1000
build:
	docker build --tag=db:demo    --rm=true ./db
	docker build --tag=app:demo   --rm=true ./app
	docker build --tag=sink:demo  --rm=true ./sink
	docker build --tag=load:demo  --rm=true ./load

run:
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 app:demo
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name sink  --net host --entrypoint /usr/local/openresty/luajit/bin/luajit sink:demo worker.lua

dev:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -v `pwd`/app/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf app:demo
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

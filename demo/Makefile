MAX ?= 1000
PG_URL = "postgresql://postgres:password@127.0.0.1:5432/lua-app?sslmode=disable"
PROM_CONF = "/etc/prometheus/prometheus.yml"
PROM_DATA = "/prometheus"
PROM_LOCAL= "stats/data/prometheus"
GRAF_DATA = "/var/lib/grafana"
GRAF_LOCAL= "stats/data/grafana"
LUAJIT    = "/usr/local/openresty/luajit/bin/luajit"
NGINX_CONF= "/usr/local/openresty/nginx/conf/nginx.conf"
NGINX_BIN = "/usr/local/openresty/nginx/sbin/nginx"
NODE_STATS= "loadavg,netdev,meminfo,stat,vmstat"
BLOCKED_IF= "^(lo|eth|tun)*$"

get-node-exporter:
	wget https://github.com/prometheus/node_exporter/releases/download/v0.13.0/node_exporter-0.13.0.linux-amd64.tar.gz
	tar xzp --strip-components=1 -f node_exporter-0.13.0.linux-amd64.tar.gz node_exporter-0.13.0.linux-amd64/node_exporter
	rm -rf node_exporter-0.13.0.linux-amd64.tar.gz

pull:
	#docker pull justwatchcom/sql_exporter
	docker pull fish/nginx-exporter:latest
	docker pull oliver006/redis_exporter:latest
	docker pull prom/prometheus:latest
	docker pull grafana/grafana:latest
	docker pull redis:alpine

build:
	docker build --tag=db:demo    --rm=true ./db
	docker build --tag=app:demo   --rm=true ./app
	docker build --tag=sink:demo  --rm=true ./sink
	docker build --tag=load:demo  --rm=true ./load

run-stats:
	docker run -d --name nexp  --net host -p 127.0.0.1:9113:9113 fish/nginx-exporter -nginx.scrape_uri=http://127.0.0.0.8000/stats
	docker run -d --name rexp  --net host -p 127.0.0.1:9121:9121 oliver006/redis_exporter -redis.addr=127.0.0.1:6379
	docker run -d --name pexp  --net host -p 127.0.0.1:8080:8080 -v `pwd`/stats/sql_exporter.yml:/conf.yml -e CONFIG=/conf.yml sql_exporter:5e92c626
	docker run -d --name prom  --net host -p 127.0.0.1:9090:9090 -v `pwd`/stats/prometheus.yml:$(PROM_CONF) -v `pwd`/$(PROM_LOCAL):$(PROM_DATA) prom/prometheus
	docker run -d --name graf  --net host -p 127.0.0.1:3000:3000 -v `pwd`/$(GRAF_LOCAL):$(GRAF_DATA) grafana/grafana
	./node_exporter -collectors.enabled "$(NODE_STATS)" -collector.netdev.ignored-devices "$(BLOCKED_IF)"

run:
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 app:demo
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name sink0 --net host --entrypoint $(LUAJIT) sink:demo worker.lua

dev:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 -v `pwd`/app/nginx.conf:$(NGINX_CONF) app:demo
	docker run -d --name sink  --net host -v `pwd`/sink/worker.lua:/src/ --entrypoint $(LUAJIT) sink:demo worker.lua

load-test:
	docker run -it --net host --entrypoint $(LUAJIT) load:demo batch-posts.lua --limit $(MAX)

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
	docker exec -it app $(NGINX_BIN) -s reload

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
	docker rm sink0
	docker run -d --name sink0  --net host --entrypoint $(LUAJIT) sink:demo worker.lua

add-sinks:
	docker run -d --name sink1  --net host --entrypoint $(LUAJIT) sink:demo worker.lua
	docker run -d --name sink2  --net host --entrypoint $(LUAJIT) sink:demo worker.lua
	docker run -d --name sink3  --net host --entrypoint $(LUAJIT) sink:demo worker.lua

rm-sinks:
	docker stop sink1 || true
	docker stop sink2 || true
	docker stop sink3 || true
	docker rm   sink1 || true
	docker rm   sink2 || true
	docker rm   sink3 || true

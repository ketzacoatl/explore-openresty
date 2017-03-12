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
BLOCKED_IF= "^(lo|eth|tun)*$$"

# download and extract the node_exporter executable from github so we can run it
get-node-exporter:
	wget https://github.com/prometheus/node_exporter/releases/download/v0.13.0/node_exporter-0.13.0.linux-amd64.tar.gz
	tar xzp --strip-components=1 -f node_exporter-0.13.0.linux-amd64.tar.gz node_exporter-0.13.0.linux-amd64/node_exporter
	rm -rf node_exporter-0.13.0.linux-amd64.tar.gz

# pre-game the upstream docker images used in this demo
pull:
	#docker pull justwatchcom/sql_exporter
	docker pull fish/nginx-exporter:latest
	docker pull oliver006/redis_exporter:latest
	docker pull prom/prometheus:latest
	docker pull grafana/grafana:latest
	docker pull redis:alpine

# build the docker custom images used in this demo
build:
	docker build --tag=db:demo    --rm=true ./db
	docker build --tag=app:demo   --rm=true ./app
	docker build --tag=sink:demo  --rm=true ./sink
	docker build --tag=load:demo  --rm=true ./load

# run the stats/metrics stack (prometheus, various exporters, grafana)
run-stats:
	docker run -d --name nexp  --net host -p 127.0.0.1:9113:9113 fish/nginx-exporter -nginx.scrape_uri=http://127.0.0.0.8000/stats
	docker run -d --name rexp  --net host -p 127.0.0.1:9121:9121 oliver006/redis_exporter -redis.addr=127.0.0.1:6379
	docker run -d --name pexp  --net host -p 127.0.0.1:8080:8080 -v `pwd`/stats/sql_exporter.yml:/conf.yml -e CONFIG=/conf.yml sql_exporter:5e92c626
	docker run -d --name prom  --net host -p 127.0.0.1:9090:9090 -v `pwd`/stats/prometheus.yml:$(PROM_CONF) -v `pwd`/$(PROM_LOCAL):$(PROM_DATA) prom/prometheus
	docker run -d --name graf  --net host -p 127.0.0.1:3000:3000 -v `pwd`/$(GRAF_LOCAL):$(GRAF_DATA) grafana/grafana
	./node_exporter -collectors.enabled "$(NODE_STATS)" -collector.netdev.ignored-devices $(BLOCKED_IF) &
	ps aux | grep node_exporter | head -n 1

# run the webapp stack (lua/openresty, db, redis, worker/sink)
run:
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 app:demo
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name sink0 --net host --entrypoint $(LUAJIT) sink:demo worker.lua

# run the webapp stack, in dev mode (mount the lua apps - skips docker build during dev)
dev:
	docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
	docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 -v `pwd`/app/nginx.conf:$(NGINX_CONF) app:demo
	docker run -d --name sink  --net host -v `pwd`/sink/worker.lua:/src/ --entrypoint $(LUAJIT) sink:demo worker.lua

# run a basic load test, using MAX from cli, or default to 1000
load-test:
	time docker run -it --net host --entrypoint $(LUAJIT) load:demo batch-posts.lua --limit $(MAX)

# run a minimal test with 10 messages, and cat them back out with /list API
load-test-min:
	docker run -it --net host --entrypoint $(LUAJIT) load:demo batch-posts.lua --limit 10 --list --exact

# run a much bigger test, 100K messages
load-test-100K:
	time docker run -it --net host --entrypoint $(LUAJIT) load:demo batch-posts.lua --limit 100000  --exact

# run a more massive test, 1 Million messages
load-test-1M:
	time docker run -it --net host --entrypoint $(LUAJIT) load:demo batch-posts.lua --limit 1000000 --exact

# get a shell in the webapp container
shell-app:
	docker exec -it app /bin/sh

# get a shell in the worker container
shell-sink:
	docker exec -it sink /bin/sh

# get a shell in the redis container
shell-redis:
	docker exec -it redis redis-cli

# get a shell in the load container
shell-load:
	docker run --rm -it --net host -v `pwd`/load/load-test.lua:/src/load-test.lua --entrypoint /bin/sh load:demo

# stop and rm the docker containers running the webapp stack
clean:
	docker stop db     || true
	docker stop app    || true
	docker stop sink   || true
	docker stop redis  || true
	docker rm   db     || true
	docker rm   app    || true
	docker rm   sink   || true
	docker rm   redis  || true

# stop and rm the docker containers running the stats/metrics stack
clean-stats:
	docker stop graf    || true
	docker stop prom    || true
	docker stop nexp    || true
	docker stop rexp    || true
	docker stop pexp    || true
	docker rm   graf    || true
	docker rm   prom    || true
	docker rm   nexp    || true
	docker rm   rexp    || true
	docker rm   pexp    || true
	pkill node_exporter || true

# rm -rf prometheus stats data
rmrf-stats:
	#rm -rf stats/data/grafana/*
	du -sh stats/data/prometheus/
	sudo rm -rf stats/data/prometheus/*

# reload nginx inside the webapp (helpful when in dev mode)
reload:
	docker exec -it app $(NGINX_BIN) -s reload

# tail the nginx error log from openresty in the webapp container
logs-app:
	docker exec -it app tail -f /usr/local/openresty/nginx/error.log

# count the number of posts in the database
count-posts:
	docker exec -it db psql -U postgres -d lua-app -c 'SELECT COUNT(*) FROM posts;'

# cat ALL posts in the database
cat-posts:
	docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'

# count the number of msgs in the queue
count-queue:
	docker exec -it redis redis-cli -c LLEN enqueued
	docker exec -it redis redis-cli -c LLEN processing

# cat ALL msg in the queue
cat-queue:
	docker exec -it redis redis-cli -c LRANGE enqueued 0 -1

# use curl to POST 3 messages to the webapp
post-msgs:
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","password":"xyz"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 2, "username":"foo","password":"foo"}' localhost:8000/
	curl -i -H "Content-Type: application/json" -X POST -d '{"id": 3, "username":"bar","password":"bar"}' localhost:8000/

# use curl to retrieve top messages from the '/list' endpoint
curl-msgs:
	curl -i -H "Content-Type: application/json" localhost:8000/list

# the sink will not attempt to reconnect if it fails to connect to the database, use this to restart it
rerun-sink:
	docker rm sink0
	docker run -d --name sink0  --net host --entrypoint $(LUAJIT) sink:demo worker.lua

# we start one sink by default, this starts 3 more for 4 total
add-sinks:
	docker run -d --name sink1  --net host --entrypoint $(LUAJIT) sink:demo worker.lua
	docker run -d --name sink2  --net host --entrypoint $(LUAJIT) sink:demo worker.lua
	docker run -d --name sink3  --net host --entrypoint $(LUAJIT) sink:demo worker.lua

# remove the extra sinks (leave sink0)
rm-sinks:
	docker stop sink1 || true
	docker stop sink2 || true
	docker stop sink3 || true
	docker rm   sink1 || true
	docker rm   sink2 || true
	docker rm   sink3 || true

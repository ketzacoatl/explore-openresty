## DEMO: Exploring Queues with Lua/OpenResty

I believe the only requirement is that docker is installed/available.. YMMV


Explain RPOPLPUSH - and redis and how the queue functions with one/multiple workers, keep messages on processing list to ensure dataloss is minimized.

check data/json parsing, should return error, not 200 OK and "saved" - add this bit to demo too

### Build the Docker Images

```
ᐅ make build
```



### Run the Webapp Stack!

```
ᐅ make run
docker run -d --name db    --net host -p 127.0.0.1:5342:5432 db:demo
fc77038db3ba1f4b2b1639e1b1e5ff35ca0f011850daa844213bde9a382b2676
docker run -d --name app   --net host -p 127.0.0.1:8000:8000 -p 127.0.0.1:9145:9145 app:demo
4131b5cf088b917f0291b17756a69b0f6954862834f09958bec0878cb495234e
docker run -d --name redis --net host -p 127.0.0.1:6379:6379 redis:alpine
5694fa3a1baf4f210d45e5c351db355b47ca0bf9ff85be09ec548c281860e904
docker run -d --name sink0 --net host --entrypoint "/usr/local/openresty/luajit/bin/luajit" sink:demo worker.lua
f0ebf7fe7f52b961a8ad9275996a0beb3a16a9224d5764bbf8e8cdadda204884
```

When we start the database for the very first time, there is a moment needed to initialize it. If the sink attempts to connect during this time, it'll fail (and won't re-attempt the connection, though that would be easy to add). It is nice to be able to demo, as it helps to make the steps more clear.

No stats running:

```
ᐅ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
5694fa3a1baf        redis:alpine        "docker-entrypoint.sh"   2 minutes ago       Up 2 minutes                            redis
4131b5cf088b        app:demo            "/usr/local/openresty"   2 minutes ago       Up 2 minutes                            app
fc77038db3ba        db:demo             "docker-entrypoint.sh"   2 minutes ago       Up 2 minutes                            db
```

### Are there any messages in the db?

We have two options for this.

1) hit the webapp's `/list` endpoint:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 15:33:47 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":{}}
```

2) cat the db table:

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id | data
----+------
(0 rows)
```

We can also run a `count(*)` on the posts:

```
ᐅ make count-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT COUNT(*) FROM posts;'
 count
-------
     0
(1 row)
```



### The Queue is Empty

Cat the queue:

```
ᐅ make cat-queue
docker exec -it redis redis-cli -c LRANGE enqueued 0 -1
(empty list or set)
```

Redis version of `count()`:

```
ᐅ make count-queue
docker exec -it redis redis-cli -c LLEN enqueued
(integer) 0
docker exec -it redis redis-cli -c LLEN processing
(integer) 0
```



### Run minimal test - curl it!

Let us send in a few messages (POST requests), and see the path those messages take through the distributed app.

```
ᐅ make post-msgs
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","password":"xyz"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 15:49:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"xyz","username":"xyz","id":1}}
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 2, "username":"foo","password":"foo"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 15:49:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"foo","username":"foo","id":2}}
curl -i -H "Content-Type: application/json" -X POST -d '{"id": 3, "username":"bar","password":"bar"}' localhost:8000/
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 15:49:05 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"status":"saved","msg":{"password":"bar","username":"bar","id":3}}
```

These are responses from the webapp, confirming the messages have been accepted for processing. Yay!

As noted previously, the worker / data processing sink is not yet running (see `docker ps` above). Thus, the messages are not yet in the database:

```
ᐅ make cat-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT * FROM posts;'
 id | data
----+------
(0 rows)
```

They are sitting in the queue:

```
ᐅ make cat-queue
docker exec -it redis redis-cli -c LRANGE enqueued 0 -1
1) "{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"
2) "{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"
3) "{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"
```

Let's restart that sink and confirm the messages are processed:

```
ᐅ make rerun-sink
docker rm sink0
sink0
docker run -d --name sink0  --net host --entrypoint "/usr/local/openresty/luajit/bin/luajit" sink:demo worker.lua
551a4ca08d66870e0ef3b0154f3d0641174561ada2ca023cb21aa661f2d4e271
```

It's online:

```
ᐅ docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
551a4ca08d66        sink:demo           "/usr/local/openresty"   3 seconds ago       Up 2 seconds                            sink0
5694fa3a1baf        redis:alpine        "docker-entrypoint.sh"   23 minutes ago      Up 23 minutes                           redis
4131b5cf088b        app:demo            "/usr/local/openresty"   23 minutes ago      Up 23 minutes                           app
fc77038db3ba        db:demo             "docker-entrypoint.sh"   23 minutes ago      Up 23 minutes                           db
```

Are those messages still in the Queue?

```
ᐅ make cat-queue
docker exec -it redis redis-cli -c LRANGE enqueued 0 -1
(empty list or set)
```

OK, so the messages ought to be in the database?

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

Retrive those msg via the HTTP API:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 16:01:32 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"password\":\"bar\",\"username\":\"bar\",\"id\":3}"},{"data":"{\"password\":\"foo\",\"username\":\"foo\",\"id\":2}"},{"data":"{\"password\":\"xyz\",\"username\":\"xyz\",\"id\":1}"}]}
```



### "mini" batch/load tests

Send in 10 POSTs and retrieve the top entries from the DB:

```
ᐅ make load-test-min

--exact enabled, will use --limit as the number of posts to send
Let us post a bunch of messages to the service:
We will print 10 messages this time..
POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":1}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":2}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":3}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":4}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":5}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":6}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":7}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":8}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--15-06-18","id":9}}

Let us retrieve the top posts saved/written to the service:
{"msg":[{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":9}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":8}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":7}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":6}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":5}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":4}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":3}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":1}"},{"data":"{\"now\":\"03-12-2017--15-06-18\",\"id\":2}"},{"data":"{\"now\":\"03-12-2017--14-34-47\",\"id\":794206}"}]}

```



### Start the Stats Framework

Retrieve the `node_exporter` executable from github:

```
ᐅ make get-node-exporter
wget https://github.com/prometheus/node_exporter/releases/download/v0.13.0/node_exporter-0.13.0.linux-amd64.tar.gz
--2017-03-14 16:03:09--  https://github.com/prometheus/node_exporter/releases/download/v0.13.0/node_exporter-0.13.0.linux-amd64.tar.gz
Resolving github.com (github.com)... 192.30.253.112, 192.30.253.113
Connecting to github.com (github.com)|192.30.253.112|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://github-cloud.s3.amazonaws.com/releases/9524057/f0d15d2a-b3e2-11e6-82b4-0ff3938151de.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAISTNZFOVBIJMK3TQ%2F20170314%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20170314T200309Z&X-Amz-Expires=300&X-Amz-Signature=40af1ceb8b745c5fe08ac36f08bb2602f33a1e74902550051d6422c21159ba56&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Dnode_exporter-0.13.0.linux-amd64.tar.gz&response-content-type=application%2Foctet-stream [following]
--2017-03-14 16:03:10--  https://github-cloud.s3.amazonaws.com/releases/9524057/f0d15d2a-b3e2-11e6-82b4-0ff3938151de.gz?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAISTNZFOVBIJMK3TQ%2F20170314%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20170314T200309Z&X-Amz-Expires=300&X-Amz-Signature=40af1ceb8b745c5fe08ac36f08bb2602f33a1e74902550051d6422c21159ba56&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Dnode_exporter-0.13.0.linux-amd64.tar.gz&response-content-type=application%2Foctet-stream
Resolving github-cloud.s3.amazonaws.com (github-cloud.s3.amazonaws.com)... 52.216.0.120
Connecting to github-cloud.s3.amazonaws.com (github-cloud.s3.amazonaws.com)|52.216.0.120|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 3795616 (3.6M) [application/octet-stream]
Saving to: ‘node_exporter-0.13.0.linux-amd64.tar.gz’

100%[==============================================>] 3,795,616    381KB/s   in 9.0s

2017-03-14 16:03:19 (411 KB/s) - ‘node_exporter-0.13.0.linux-amd64.tar.gz’ saved [3795616/3795616]

tar xzp --strip-components=1 -f node_exporter-0.13.0.linux-amd64.tar.gz node_exporter-0.13.0.linux-amd64/node_exporter
rm -rf node_exporter-0.13.0.linux-amd64.tar.gz
```

Run the stats/metrics framework:

```
ᐅ make run-stats
docker run -d --name nexp  --net host -p 127.0.0.1:9113:9113 fish/nginx-exporter -nginx.scrape_uri=http://127.0.0.0.8000/stats
f346df3c7627043015b02b59bed65637cdadbaa2a2e6581f91bb0f71323f6074
docker run -d --name rexp  --net host -p 127.0.0.1:9121:9121 oliver006/redis_exporter -redis.addr=127.0.0.1:6379
abf6cf1c7961cf149bebe6f86e36cb2acf637d137a052c7025266de0737efa70
docker run -d --name pexp  --net host -p 127.0.0.1:8080:8080 -v `pwd`/stats/sql_exporter.yml:/conf.yml -e CONFIG=/conf.yml sql_exporter:5e92c626
4977457a59d9e13ddaaa9c310f3919650c1a7f41e4a0801bc18683ffc8c3f34a
docker run -d --name prom  --net host -p 127.0.0.1:9090:9090 -v `pwd`/stats/prometheus.yml:"/etc/prometheus/prometheus.yml" -v `pwd`/"stats/data/prometheus":"/prometheus" prom/prometheus
d8139b739d431e1628df571bd673416373029262e85af92a52adce09b3f19f75
docker run -d --name graf  --net host -p 127.0.0.1:3000:3000 -v `pwd`/"stats/data/grafana":"/var/lib/grafana" grafana/grafana
311f272edee86c2a22dbfc524ab58548f68cf60d7d8470b70fcddd9e154e33b6
./node_exporter -collectors.enabled ""loadavg,netdev,meminfo,stat,vmstat"" -collector.netdev.ignored-devices "^(lo|eth|tun)*$" &
ps aux | grep node_exporter | head -n 1
INFO[0000] Starting node_exporter (version=0.13.0, branch=master, revision=006d1c7922b765f458fe9b92ce646641bded0f52)  source=node_exporter.go:135
INFO[0000] Build context (go=go1.7.3, user=root@75db7098576a, date=20161126-13:11:09)  source=node_exporter.go:136
INFO[0000] Enabled collectors:                           source=node_exporter.go:155
INFO[0000]  - vmstat                                     source=node_exporter.go:157
INFO[0000]  - loadavg                                    source=node_exporter.go:157
INFO[0000]  - netdev                                     source=node_exporter.go:157
INFO[0000]  - meminfo                                    source=node_exporter.go:157
INFO[0000]  - stat                                       source=node_exporter.go:157
INFO[0000] Listening on :9100                            source=node_exporter.go:176
user     22613  0.0  0.1  90432  7816 pts/21   Sl+  12:17   0:00 ./node_exporter -collectors.enabled loadavg,netdev,meminfo,stat,vmstat -collector.netdev.ignored-devices ^(lo|eth|tun)*$
```

### Grafana Dashboards

Grab the dashboard JSON to import:

```

```

Import the dashboard into Grafana.

Open the [DEMO Dashboard](http://localhost:3000/dashboard/db/demo?var-role=lua-app&var-status=200&var-node=demo&var-database=lua-app&from=now-5m&to=now) in Grafana.



## More load, how about 1M messages?

OK, we have the webapp and metrics stacks running, let's run some more serious load though this system to see what it's capable of doing.

### Post 1k messages, just to make sure everything is in place

Note that we pipe the output to `/dev/null` for this because the load test will print out info about each POST, and we want to minimize impact on the demo (from all that data in the output).

```
ᐅ make load-test > /dev/null
```

OK, running that was fast, let's see what happened:

```
ᐅ docker ps -a | grep load:demo
5e949228b521  load:demo  "/usr/local/openresty"   30 seconds ago Exited (0) 30 seconds ago  happy_allen
```

We want the name of the container, in this case `happy_allen`, to use in looking up the logs:

```
ᐅ docker logs happy_allen | less

--exact disabled, pick a pseudo-random number up to --limit
Let us post a bunch of messages to the service:
We will print 897 messages this time..
POST success! {"status":"saved","msg":{"now":"03-12-2017--17-56-44","id":1}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--17-56-44","id":2}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--17-56-44","id":3}}

POST success! {"status":"saved","msg":{"now":"03-12-2017--17-56-44","id":4}}

...
```

To add this up.. we first sent in 3 messages, then 10 more, and now 897, so there ought to be 910 messages in the database. Let's check:

```
ᐅ make count-posts
docker exec -it db psql -U postgres -d lua-app -c 'SELECT COUNT(*) FROM posts;'
 count
-------
   899    <------ ADD IN A REPASTE ON THE NEXT RUN
(1 row)
```

Let's curl those posts to see (via the HTTP API):

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 18:08:58 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":896}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":895}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":894}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":893}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":892}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":891}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":890}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":889}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":888}"},{"data":"{\"now\":\"03-12-2017--17-56-45\",\"id\":887}"}]}
```

^^^^ REPLACE THAT POST WITH A REPASTE AFTER RUNNING THIS A SECOND TIME.


### 1 Million messages..

We redirect output to `/dev/null` as noted in a previous run. We also `time` this run to see how long it takes to submit those 1M messages:

```
ᐅ make load-test-1M > /dev/null

```

OK, while that runs, let's do a few other things..


### Add Workers (Data Processing Sinks)

```
ᐅ make add-sinks
docker run -d --name sink1  --net host --entrypoint "/usr/local/openresty/luajit/bin/luajit" sink:demo worker.lua
f8c5a0b658f498353d13795c544ffd28ebab760bc5186718ad948b5829c59815
docker run -d --name sink2  --net host --entrypoint "/usr/local/openresty/luajit/bin/luajit" sink:demo worker.lua
bc3826b3b0b1222cc14957d80b5db429cafd3738b5800e05a4cc2faa99483444
docker run -d --name sink3  --net host --entrypoint "/usr/local/openresty/luajit/bin/luajit" sink:demo worker.lua
9632c8c640ce6707cd0ce7814944196fcf2a4bd04da7263eafd6bc9a38aed836
```

We'll now see those running in `docker ps`:

```
ᐅ docker ps
CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS              PORTS               NAMES
0bb4af73bc9c        sink:demo                  "/usr/local/openresty"   6 seconds ago       Up 5 seconds                            sink3
50b15b1b8beb        sink:demo                  "/usr/local/openresty"   6 seconds ago       Up 5 seconds                            sink2
4868b8767600        sink:demo                  "/usr/local/openresty"   6 seconds ago       Up 5 seconds                            sink1
```


### Check that 1M messages really are there...

Well,  to be specific... there ought to be 1,000,910 messages in the database when this is all done.



Note, the vast majority of these messages will all be in "order", as the workers are respecting the order of items in the queue, and even with multiple workers, they are retrieving messages in that order:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 18:51:21 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513785}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513784}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513781}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513783}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513782}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513780}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513779}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513778}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513777}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513776}"}]}
```

However, if two workers A and B grab their messages (with A pulling its message first), B could finish first and put its message into the database before A does:

```
ᐅ make curl-msgs
curl -i -H "Content-Type: application/json" localhost:8000/list
HTTP/1.1 200 OK
Server: openresty/1.11.2.2
Date: Sun, 12 Mar 2017 18:51:21 GMT
Content-Type: application/json; charset=utf-8
Transfer-Encoding: chunked
Connection: keep-alive

{"msg":[{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513785}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513784}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513781}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513783}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513782}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513780}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513779}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513778}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513777}"},{"data":"{\"now\":\"03-12-2017--18-27-39\",\"id\":513776}"}]}
```

### Remove / Drop the Workers (sinks)

```
ᐅ make rm-sinks
docker stop sink1 || true
sink1
docker stop sink2 || true
sink2
docker stop sink3 || true
sink3
docker rm   sink1 || true
sink1
docker rm   sink2 || true
sink2
docker rm   sink3 || true
sink3
```


### Stop the Webapp Stack

```
ᐅ make clean
docker stop db     || true
db
docker stop app    || true
app
docker stop sink   || true
sink
docker stop redis  || true
redis
docker rm   db     || true
db
docker rm   app    || true
app
docker rm   sink   || true
sink
docker rm   redis  || true
redis
```


### Stop Stats Framework

```
ᐅ make clean-stats
docker stop graf   || true
graf
docker stop prom   || true
prom
docker stop nexp   || true
nexp
docker stop rexp   || true
rexp
docker stop pexp   || true
pexp
docker rm   graf   || true
graf
docker rm   prom   || true
prom
docker rm   nexp   || true
nexp
docker rm   rexp   || true
rexp
docker rm   pexp   || true
pexp
```


### Clear Prometheus/Stats Data (rm -rf)

```
ᐅ make rmrf-stats
#rm -rf stats/data/grafana/*
du -sh stats/data/prometheus/
150M   stats/data/prometheus/
sudo rm -rf stats/data/prometheus/*
```


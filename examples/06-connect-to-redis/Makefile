build:
	docker build --tag=app:6    --rm=true .

# add "-v `pwd`:/usr/local/openresty/nginx/conf/" to the app for local dev
run:
	docker run -d --name redis  --net host -p 127.0.0.1:6379:6379 redis:alpine
	docker run -d --name app    --net host -p 127.0.0.1:8000:8000 app:6

clean:
	docker stop redis  || true
	docker stop app    || true
	docker rm   redis  || true
	docker rm   app    || true

reload:
	docker exec -it app   /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
	docker exec -it app   tail -f /usr/local/openresty/nginx/error.log

cat-posts:
	docker exec -it redis redis-cli -c LRANGE queue 0 -1

app-shell:
	docker exec -it app   /bin/sh

redis-shell:
	docker exec -it redis redis-cli

test:
	curl -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/

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

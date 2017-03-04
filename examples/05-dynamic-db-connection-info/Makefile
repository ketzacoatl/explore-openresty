build:
	docker build --tag=db:5  --rm=true ./db
	docker build --tag=app:5 --rm=true ./app

# add "-v `pwd`/app:/usr/local/openresty/nginx/conf/" to the app for local dev
run:
	docker run -d --name db  --net host -p 127.0.0.1:5342:5432 db:5
	docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:5

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

app-shell:
	docker exec -it app /bin/sh

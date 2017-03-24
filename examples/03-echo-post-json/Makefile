build:
	docker build --tag=app:3 --rm=true ./

run:
	docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:3

dev:
	docker run -d --name app --net host -p 127.0.0.1:8000:8000 -v `pwd`:/usr/local/openresty/nginx/conf/ app:3

clean:
	docker stop app || true
	docker rm   app || true

reload:
	docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
	docker exec -it app tail -f /usr/local/openresty/nginx/error.log

get:
	curl -i localhost:8000

post:
	curl -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","pass":"foobar"}' localhost:8000/

post-invalid:
	curl -H "Content-Type: application/json" -X POST -d '{"id": 1, "username":"xyz","pass:}' localhost:8000/

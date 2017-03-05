build:
	docker build --tag=app:8 --rm=true ./

run:
	docker run -d --name app --net host -p 127.0.0.1:8000:8000 app:8

dev:
	docker run --rm -it --name app --net host --entrypoint /bin/sh -v `pwd`/app:/src app:8

clean:
	docker stop app || true
	docker rm   app || true

reload:
	docker exec -it app /usr/local/openresty/nginx/sbin/nginx -s reload

logs:
	docker exec -it app tail -f /usr/local/openresty/nginx/error.log

test:
	curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/get
	curl -i -H "Content-Type: application/json"                                                  localhost:8000/get
	curl -i -H "Content-Type: application/json"                                                  localhost:8000/post
	curl -i -H "Content-Type: application/json" -X POST -d '{"username":"xyz","password":"xyz"}' localhost:8000/post

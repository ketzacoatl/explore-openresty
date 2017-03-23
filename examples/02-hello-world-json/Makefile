run:
	docker run --name lua --rm --volume `pwd`:/usr/local/openresty/nginx/conf/ -p 127.0.0.1:8000:8000 openresty/openresty:alpine

reload:
	docker exec -it lua /usr/local/openresty/nginx/sbin/nginx -s reload

error-logs:
	docker exec -it lua cat /usr/local/openresty/nginx/error.log
logs:
	docker logs lua

get:
	curl -i localhost:8000

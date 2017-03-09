FROM openresty/openresty:alpine-fat

EXPOSE 8000
# install package dependencies for our lua webapp
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install nginx-lua-prometheus
# nginx config for/with lua webapp
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
# nginx config to publish stats/metrics for prometheus to scrape
ADD prom.conf  /usr/local/openresty/nginx/conf/prom.conf
ENV REDIS_HOST 127.0.0.1
ENV DB_HOST    127.0.0.1
ENV DB_USER    postgres
ENV DB_PASS    password
ENV DB_NAME    lua-app

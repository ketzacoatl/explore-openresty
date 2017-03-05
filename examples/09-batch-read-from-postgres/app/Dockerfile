FROM openresty/openresty:alpine-fat

EXPOSE 8000
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
ADD producer.lua /src/
ENV DB_HOST 127.0.0.1
ENV DB_USER postgres
ENV DB_PASS password
ENV DB_NAME lua-app

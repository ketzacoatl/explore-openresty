FROM openresty/openresty:alpine-fat

ENV REDIS_HOST 127.0.0.1
RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
ADD *.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh

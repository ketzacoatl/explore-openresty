FROM openresty/openresty:alpine-fat

ENV REDIS_HOST 127.0.0.1
ENV DB_HOST    127.0.0.1
ENV DB_USER    postgres
ENV DB_PASS    password
ENV DB_NAME    lua-app
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
ADD worker.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh

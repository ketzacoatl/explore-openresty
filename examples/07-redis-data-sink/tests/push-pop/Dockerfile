FROM openresty/openresty:alpine-fat

RUN /usr/local/openresty/luajit/bin/luarocks install lua-hiredis
ADD *.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh

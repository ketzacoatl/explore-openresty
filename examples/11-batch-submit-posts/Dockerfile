FROM openresty/openresty:alpine-fat

RUN apk add --update openssl-dev git
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install luasec
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install httpclient
RUN /usr/local/openresty/luajit/bin/luarocks install lua_cliargs
ADD batch-posts.lua /src/batch-posts.lua
WORKDIR /src/
ENTRYPOINT /usr/local/openresty/luajit/bin/luajit
CMD ["batch-posts.lua"]

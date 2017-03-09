FROM openresty/openresty:alpine-fat

RUN apk add --update openssl-dev git
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install luasec
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install httpclient
ADD get-post.lua /src/get-post.lua
WORKDIR /src/
ENTRYPOINT /usr/local/openresty/luajit/bin/luajit
CMD ["get-post.lua"]

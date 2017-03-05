FROM openresty/openresty:alpine-fat

RUN apk add --update openssl-dev git
RUN /usr/local/openresty/luajit/bin/luarocks install luasocket
RUN /usr/local/openresty/luajit/bin/luarocks install luasec
RUN /usr/local/openresty/luajit/bin/luarocks install lua-cjson
RUN /usr/local/openresty/luajit/bin/luarocks install httpclient
ADD load-test.lua /src/
WORKDIR /src/
ENTRYPOINT /bin/sh

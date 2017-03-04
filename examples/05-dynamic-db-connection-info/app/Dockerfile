FROM openresty/openresty:alpine-fat

EXPOSE 8000
ENV DB_HOST 127.0.0.1
ENV DB_USER postgres
ENV DB_PASS password
ENV DB_NAME lua-app
RUN /usr/local/openresty/luajit/bin/luarocks install pgmoon
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf

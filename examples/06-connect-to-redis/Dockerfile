FROM openresty/openresty:alpine-fat

EXPOSE 8000
ENV REDIS_HOST 127.0.0.1
RUN /usr/local/openresty/luajit/bin/luarocks install lua-resty-reqargs
ADD nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf

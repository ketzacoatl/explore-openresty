FROM postgres:alpine
ENV  POSTGRES_PASSWORD password
ENV  POSTGRES_DB       lua-app
ADD  init.sql /docker-entrypoint-initdb.d/
RUN  echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' > /etc/nsswitch.conf


FROM postgres:alpine
ENV  POSTGRES_PASSWORD password
ENV  POSTGRES_DB       lua-app
ADD  init.sql /docker-entrypoint-initdb.d/

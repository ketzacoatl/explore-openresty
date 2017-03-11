#!/bin/sh
docker inspect $1 | jq '.[0].NetworkSettings.Networks[].IPAddress' | sed 's/"//g'

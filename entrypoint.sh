#! /usr/bin/env bash

service php8.2-fpm start
service postgresql start
until pg_isready -q; do echo "waiting for postgres..."; sleep 1; done

exec "$@"
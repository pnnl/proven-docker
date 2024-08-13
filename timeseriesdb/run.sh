#!/bin/sh

source .env
docker compose up &
bash -c 'echo -n "Waiting port 5432 .."; for _ in `seq 1 40`; do echo -n .; sleep 5; nc -z localhost 5432 && echo " Port 5432 Open." && exit ; done; echo " Port 5432 Timeout!" >&2; exit 1'
docker exec -it gridappsd_ts psql -U $PG_USER -c "DROP DATABASE IF EXISTS gridappsd_ts ;"
docker exec -it gridappsd_ts psql -U $PG_USER -c "CREATE DATABASE gridappsd_ts WITH OWNER = postgres ENCODING = 'UTF8' LC_COLLATE = 'C.UTF-8' LC_CTYPE = 'C.UTF-8' LOCALE_PROVIDER = 'libc'"
docker exec -it gridappsd_ts psql -U $PG_USER -d gridappsd_ts -c "CREATE EXTENSION IF NOT EXISTS timescaledb ;"
docker exec -it gridappsd_ts psql -U $PG_USER -d gridappsd_ts -c "CREATE SCHEMA api ;"
echo "CREATING SCHEMA api !!!!!!!!!"
cat create_roles.sql |  docker exec -i gridappsd_ts psql -U $PG_USER -d gridappsd_ts 
cat create_tables.sql |  docker exec -i gridappsd_ts psql -U $PG_USER -d gridappsd_ts 
cat grant_privs.sql |  docker exec -i gridappsd_ts psql -U $PG_USER -d gridappsd_ts 
docker-compose -f docker-rest.yml up &

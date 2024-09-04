#!/bin/bash

NEW_DB_PASSWORD=$1
NEW_DB_USER=$2
NEW_DB_USER_PASSWORD=$3
cd "$HOME"
echo "start user db restoring at $(date)"
psql -c 'CREATE USER cloudsqladmin'
psql -c 'ALTER USER cloudsqladmin WITH CREATEROLE CREATEDB SUPERUSER REPLICATION'
psql -c 'CREATE ROLE cloudsqlsuperuser CREATEROLE CREATEDB SUPERUSER REPLICATION'
psql -c 'CREATE ROLE cloudsqlimportexport CREATEROLE CREATEDB'
psql -c "ALTER USER postgres PASSWORD '$NEW_DB_PASSWORD'"




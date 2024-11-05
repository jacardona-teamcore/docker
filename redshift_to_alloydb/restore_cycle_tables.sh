#!/bin/bash
ID=$1
DB=$2
FOLDER=$3
FOLDER_POSTGRES=$4
KEY="${FOLDER_POSTGRES}/key"
export $(xargs <$FOLDER_POSTGRES/parameters_cnx.sh)

SCHEMA_TABLE=$(su postgres -c "psql -h localhost -p 5432 -U postgres -tAc \"select esquema||'.'||tabla as result from temporal.tables_load where id = ${ID}\" ${DB}")

COUNT=$(ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "PGPASSWORD=$REDSHIFT_PASSWORD psql -U $REDSHIFT_USER -h $REDSHIFT_IP -p $REDSHIFT_PORT -tAc \"select count(1) from ${SCHEMA_TABLE} \" $DB")

if [ "${COUNT}" -eq 0 ]; then
    su postgres -c "psql -h localhost -p 5432 -U postgres -c \"update temporal.tables_load set estado = 'VACIA', fin = now() where id = ${ID}\" ${DB}"
else
    su postgres -c "psql -h localhost -p 5432 -U postgres -c \"update temporal.tables_load set redshift_count =${COUNT} where id = ${ID}\" ${DB}"
    su postgres -c "psql -h localhost -p 5432 -U postgres -c \"select * from fnc_copy_table_info_redshift(${ID},'${FOLDER}')\" ${DB}"
    su postgres -c "psql -h localhost -p 5432 -U postgres -c \"update temporal.tables_load set estado=case when redshift_count = alloydb_count then 'CARGADA' else 'ERROR' end, fin=now() where id = ${ID}\" ${DB}"
fi
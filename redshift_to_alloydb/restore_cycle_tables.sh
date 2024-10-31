#!/bin/bash
FOLDER=$1
FOLDER_POSTGRES=$2
COMMAND="psql -h localhost -p 5432 -U postgres -tAc "

export $(xargs <$FOLDER_POSTGRES/parameters_cnx.sh)

COUNT=$(su postgres -c "$COMMAND \"SELECT COUNT(1) FROM temporal.tables_load WHERE estado='PENDIENTE'\" ${DB}")

if [ "$COUNT" -gt 0 ]; then
    
    ID=$(su postgres -c "$COMMAND \"SELECT * FROM fnc_get_load_table()\" ${DB}")
    su postgres -c "psql -h localhost -p 5432 -U postgres -c \"select * from fnc_copy_table_info_redshift(${ID},'${FOLDER}')\" ${DB}"
    
fi
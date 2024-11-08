#!/bin/bash
CLONE=$1
FOLDER=$2
SCHEMA=$3
TABLE=$4
COLUMN=$5
FILE=$1_$2

FOLDER_POSTGRES="/home/postgres"

export $(xargs <$FOLDER_POSTGRES/parameters_cnx.sh)

# Configuración de S3 y GCS
FOLDER_UNLOAD="$FOLDER_POSTGRES/unload/${FOLDER}"
FOLDER_TABLES="$FOLDER_POSTGRES/tables"

rm -rf $FOLDER_UNLOAD
mkdir -p $FOLDER_UNLOAD

# Lista de tablas
S3_PATH="${S3_BUCKET_BASE}/S3/"

# Consulta UNLOAD en Redshift para cada tabla
echo "Loading... ${SCHEMA}.${TABLE} ..."
START_TIME=$(date +%s)

rm -rf $FOLDER_POSTGRES/migration/
mkdir -p $FOLDER_POSTGRES/migration

# Ejecutar la consulta
echo "execute remote... ${SCHEMA}.${TABLE} ..."
ssh -o "StrictHostKeyChecking no" -i $FOLDER_POSTGRES/key $USERREMOTO@$INSTANCEVPN "$FOLDER_REMOTO/unload_redshift.sh $FOLDER $SCHEMA $TABLE $FOLDER_REMOTO/$FILEPARAMETERS"

echo "sync s3... ${SCHEMA}.${TABLE} ..."
/usr/local/bin/aws s3 sync $S3_BUCKET_BASE/$DB/$FOLDER/ $FOLDER_UNLOAD --quiet

echo "descompress gz... ${SCHEMA}.${TABLE} ..."
cd $FOLDER_UNLOAD
cat * > $FILE.gz
gzip -d $FILE.gz

if [ -f "$FILE" ]; then
  rm -f $FOLDER_TABLES/$FILE
else
  rm -f $FOLDER_TABLES/$TABLE
  FILE=$TABLE
fi

mv -f $FOLDER_UNLOAD/$FILE $FOLDER_TABLES/$FILE

if [ -s "$FOLDER_TABLES/$FILE" ]; then
  echo "restore alloydb... ${SCHEMA}.${TABLE} ..."
  rm -f ${FOLDER_UNLOAD}/COPY_${FILE}.sql
  COPY="\\COPY ${SCHEMA}.${TABLE}(${COLUMN}) FROM '${FOLDER_TABLES}/${FILE}' DELIMITER '|' NULL AS 'null'"
  echo $COPY > COPY_${FILE}.sql

  if [[ ${CLONE} -eq 1 ]]; then
    /usr/bin/psql -h localhost -p 5432 -U postgres ${DB} < ${FOLDER_UNLOAD}/COPY_${FILE}.sql
    rm -f ${FOLDER_TABLES}/${FILE}
    /usr/bin/psql -h localhost -p 5432 -U postgres -c "\\copy (select distinct * from ${SCHEMA}.${TABLE}) TO '${FOLDER_TABLES}/${FILE}' DELIMITER '|' NULL AS 'null';" $DB
  fi

  export PGPASSWORD="$ALLOYDB_PASSWORD"
  /usr/bin/psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB < ${FOLDER_UNLOAD}/COPY_${FILE}.sql

  COUNT=$(/usr/bin/psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -tAc "select count(1) from ${SCHEMA}.${TABLE} " $DB)

  /usr/bin/psql -h localhost -p 5432 -U postgres -tAc "update temporal.tables_load set alloydb_count=${COUNT} where esquema='${SCHEMA}' and tabla='${TABLE}'" ${DB}

  rm -f $FOLDER_TABLES/$FILE
else
  echo "El archivo '$FOLDER_TABLES/$FILE' está vacío o no existe."
fi

/usr/local/bin/aws s3 rm $S3_BUCKET_BASE/$DB/$FOLDER/ --recursive --quiet

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Finalizando backup ${SCHEMA}.${TABLE}. Duración: ${DURATION} segundos."
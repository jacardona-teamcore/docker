#!/bin/bash

SCHEMA=$1
TABLE=$2
COLUMN=$3
FILE=$1_$2

FOLDER_POSTGRES="/home/postgres"

export $(xargs <$FOLDER_POSTGRES/parameters_cnx.sh)

# Configuración de S3 y GCS
FOLDER_UNLOAD="$FOLDER_POSTGRES/unload"
FOLDER_TABLES="$FOLDER_POSTGRES/tables"

rm -rf $FOLDER_UNLOAD
mkdir -p $FOLDER_UNLOAD

# Lista de tablas
S3_PATH="${S3_BUCKET_BASE}/S3/"

# Consulta UNLOAD en Redshift para cada tabla
echo "Creando... ${SCHEMA}.${TABLE} ..."
START_TIME=$(date +%s)

rm -rf $FOLDER_POSTGRES/migration/
mkdir -p $FOLDER_POSTGRES/migration

# Ejecutar la consulta
ssh -o "StrictHostKeyChecking no" -i $FOLDER_POSTGRES/key $USERREMOTO@$INSTANCEVPN "$FOLDER_REMOTO/unload_redshift.sh $SCHEMA $TABLE $FOLDER_REMOTO/$FILEPARAMETERS"

/usr/local/bin/aws s3 sync $S3_BUCKET_BASE/$DB/ $FOLDER_UNLOAD --quiet

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
  rm -f COPY_${FILE}.sql
  COPY="\\COPY ${1}.${2}(${COLUMN}) FROM '${FOLDER_TABLES}/${FILE}' DELIMITER '|'"
  echo $COPY > COPY_${FILE}.sql
  export PGPASSWORD="$ALLOYDB_PASSWORD"
  /usr/bin/psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB < COPY_${FILE}.sql

  rm -f $FOLDER_TABLES/$FILE
else
  echo "El archivo '$FOLDER_TABLES/$FILE' está vacío o no existe."
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Finalizando backup ${SCHEMA}.${TABLE}. Duración: ${DURATION} segundos."
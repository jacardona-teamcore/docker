#!/bin/bash
FOLDER=$1
SCHEMA=$2
TABLE=$3
FILEPARAMETERS=$4
SEP=$5
echo "$FILEPARAMETERS"
export $(xargs <$FILEPARAMETERS.sh)
SEPARATOR="}"

if [ $SEP -eq 1 ]; then
        SEPARATOR="|"
fi

QUERY="UNLOAD ('SELECT * FROM ${SCHEMA}.${TABLE}' )
  TO '${S3_BUCKET_BASE}/${DB}/${FOLDER}/'
  CREDENTIALS 'aws_iam_role=${IAM_ROLE}'
  CLEANPATH
  DELIMITER '${SEPARATOR}'
  NULL AS 'null'
  ZSTD;"

export PGPASSWORD="$REDSHIFT_PASSWORD"
/usr/bin/psql -h "$REDSHIFT_IP" -p "$REDSHIFT_PORT" -U "$REDSHIFT_USER" -d "$DB" -c "$QUERY"
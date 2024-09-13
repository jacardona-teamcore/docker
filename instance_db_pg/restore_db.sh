#!/bin/bash

DB=$1
BUCKET=$2
FOLDERRESTORE=/home/restore
VERSION=16

rm -rf $FOLDERRESTORE

echo "$(date) : download files of bucket"
mkdir -p $FOLDERRESTORE
gcloud storage cp $BUCKET $FOLDERRESTORE --recursive

echo "$(date) : start descompress lz4"
find "$FOLDERRESTORE" -name "*.lz4" -print0 | while IFS= read -r -d '' file; do
  echo "Descompress : $file"
  lz4 -dc "$file" | tar xvf -
done

echo "$(date) : create folder lz4"
mkdir lz4
mv *.lz4 lz4/.

echo "$(date) : concat file tar"
cat *.tar > $DB.tar

echo "$(date) : descompress tar"
tar -xf $DB.tar

systemctl stop postgresql
sleep 15

echo "$(date) : restore database"
cp /etc/postgresql/$VERSION/main/postgresql.conf .
cp /etc/postgresql/$VERSION/main/pg_hba.conf .

rm -rf /etc/postgresql/$VERSION/main
mv latest_backup /etc/postgresql/$VERSION/main

rm -f /etc/postgresql/$VERSION/main/postgresql.conf 
rm -f /etc/postgresql/$VERSION/main/pg_hba.conf 
cp postgresql.conf /etc/postgresql/$VERSION/main/
cp pg_hba.conf /etc/postgresql/$VERSION/main/

chown -R postgres.postgres /etc/postgresql/$VERSION/main/

echo "$(date) : start postgres"
systemctl start postgresql

rm -rf $FOLDERRESTORE
rm -f /home/access/credentials.json
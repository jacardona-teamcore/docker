#!/bin/bash

DB=$1
USERPG=$2
PASS=$3
SQLCLOUD_CONNECTION=$4
FOLDER=$5

echo "$(date) : started service postgres"
su postgres -c "/usr/lib/postgresql/16/bin/postgres -c config_file=/etc/postgresql/16/main/postgresql.conf" &>/dev/null &
sleep 5

echo "$(date) : create acces to project"
gcloud config set 'auth/service_account_use_self_signed_jwt' false
gcloud auth activate-service-account --key-file /home/config/credentials.json

echo "$(date) : create instance proxy"
/home/cloud-sql-proxy --address 127.0.0.1 --port 6432 $SQLCLOUD_CONNECTION --credentials-file /home/config/credentials.json &
sleep 5
echo "$(date) : generate file backup"
mkdir -p /home/backup
chown postgres.postgres /home/backup
cd /home/backup
su postgres -c "PGPASSWORD=$PASS pg_dump -U $USERPG -h 127.0.0.1 -p 6432 -j 28 -Fd -Z0 -f $DB.dump $DB"
echo "$(date) : end db backup"

echo "$(date) : started restore"
su postgres -c "createdb $DB"
su postgres -c "pg_restore -j 28 -Fd -O -d $DB $DB.dump"
rm -Rf "$DB.dump"
echo "$(date) : end db restoring"

echo "$(date) : generate file backup_base"
su postgres -c "mkdir -p /home/backup/latest_backup"
su postgres -c "pg_basebackup -p 5432 -D /home/backup/latest_backup -Fp -Xs -P -v"
echo "$(date) : end generate file backup_base"
cd /home/backup

echo "$(date) : start comprime folder backup_base"
tar -cf $DB.tar latest_backup/

echo "$(date) : start splitting"
FILETAR="/home/backup/$DB.tar"
mkdir split
mkdir $DB
cd split
split --verbose --bytes=5120M /home/backup/$DB.tar "backup."
ls -lh .
echo "$(date) : end splitting"

for file in /home/backup/split/*; do
    echo "$file"
    lz4 --fast $file $file.lz4
done

cd /home/backup
mv /home/backup/split/*.lz4 /home/backup/$DB/.
echo "$(date) : end lz4"
rm -rf /home/backup/split/
rm -f /home/backup/$DB.tar

echo "$(date) : start send file"
gsutil -m rm -r $FOLDER/$DB/
gsutil -m cp -r /home/backup/$DB $FOLDER/
echo "$(date) : end send file"
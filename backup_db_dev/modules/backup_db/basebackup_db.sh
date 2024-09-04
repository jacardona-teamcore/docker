#!/bin/bash

PASS=$1
DB=$2

echo "start db pg_basebackup at $(date)"

mkdir -p "/mnt/disks/ssd-array/latest_backup"

PGPASSWORD=$PASS pg_basebackup -h 127.0.0.1 -p 5432 -U postgres -D /mnt/disks/ssd-array/latest_backup -Fp -Xs -P -v

cd /mnt/disks/ssd-array

#tar --use-compress-program="pigz -1 -k " -cvf "$DB".tar.gz ./latest_backup
tar -cvf "$DB".tar ./latest_backup

echo "end db pg_basebackup at $(date)"


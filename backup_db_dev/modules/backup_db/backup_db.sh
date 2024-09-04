#!/bin/bash

echo "start db backup at $(date)"

DB=$2
PASS=$1
#cd "$HOME"
cd /mnt/disks/ssd-array
PGPASSWORD=$PASS pg_dump -U postgres -h 127.0.0.1 -p 6432 -j 28 -Fd -Z0 -f "$DB".dump "$DB"
echo "end db backup at $(date)"

#!/bin/bash

DB=$1

#cd "$HOME"
echo "start db restoring at $(date)"
cd /mnt/disks/ssd-array
createdb "$DB"
pg_restore -j 28 -Fd -O -d "$DB" "$DB".dump
rm -Rf "$DB".dump

echo "end db restoring at $(date)"

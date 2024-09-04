#!/bin/bash
DB=$1
FILE=$2

cd /mnt/disks/ssd-array/
mkdir "$DB"
cd "$DB"

echo "splitting $FILE"
split --verbose --bytes=5120M "$FILE" "backup."
echo "deleting original file $FILE"
rm "$FILE"
for f in `find ./backup.?? -type f -print`;do lz4 --fast "$f" ; done
for f in `find ./backup.?? -type f -print`;do rm "$f" ; done

cd /mnt/disks/ssd-array/

gsutil -m rm -R gs://teamcore-db-backups/infra/"$DB"
gsutil -m cp -r /mnt/disks/ssd-array/"$DB" gs://teamcore-db-backups/infra/"$DB"
#!/bin/bash

DISKS=$1
echo "building logical volume with local ssd disks $DISKS $(date)"
MDADM="sudo mdadm --create /dev/md0 --level=0 --raid-devices=$DISKS"
for i in $(seq 0 $((DISKS - 1)))
do
  MDADM="$MDADM /dev/disk/by-id/google-local-nvme-ssd-$i"
done
echo "running $MDADM"
bash -c "$MDADM"

 sudo mdadm --detail --prefer=by-id /dev/md0

 sudo mkfs.ext4 -F /dev/md0

 sudo mkdir -p /mnt/disks/ssd-array
 sudo mount /dev/md0 /mnt/disks/ssd-array
 sudo chmod a+w /mnt/disks/ssd-array

 export DB_MIGRATION_WORKING_DIR=/mnt/disks/ssd-array
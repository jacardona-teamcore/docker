#!/bin/sh
echo "setting keys ..."
eval "$(ssh-agent -s)"
ssh-add /app/.ssh/id_rsa

file="/home/execute/terraform.tfvars"

file_variable() {

    rm -f $file

  cat > $file << EOF
project="$1"
region="$2"
zone="$3"
network="$4"
cluster_name="$5"
env_name="$6"
origen_project="$7"
origen_region="$8"
origen_instance="$9"
origen_db="$10"
origen_password="$11"
destinity_super_password="$12"
destinity_user="$13"
destinity_password="$14"
destinity_pg_version="$15"
pub_key="$16"
account_id="$17"
pg_bouncer_pass="$18"
EOF
}

file_variable()
cd /home/execute
cat terraform.tfvars


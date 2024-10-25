#!/bin/bash

DB=$1
REDSHIFT_IP=$2
REDSHIFT_PORT=$3
REDSHIFT_USER=$4
REDSHIFT_PASSWORD=$5
ALLOYDB_IP=$6
ALLOYDB_PORT=$7
ALLOYDB_USER=$8
ALLOYDB_PASSWORD=$9
S3_BUCKET_BASE=${10}
GCS_BUCKET=${11}
IAM_ROLE=${12}
INSTANCEVPN=${13}

DATETIME=$(date +"%Y%m%d%H%M%S")
FILEPARAMETERS="${DB}_${DATETIME}"
FOLDER_REMOTO="/home/ubuntu"
FOLDER_POSTGRES="/home/postgres"
FOLDER_BACKUP="$FOLDER_POSTGRES/backup"
USERREMOTO="ubuntu"
KEY="/home/key"

chmod 0400 $KEY

echo "$(date) : Install postgres service"
apt install -y postgresql postgresql-contrib postgresql-client
systemctl stop postgresql

echo "$(date) : Start configuration postgres"
# Copy configuration file and access to postgres user
mkdir -p $FOLDER_POSTGRES
mkdir -p $FOLDER_POSTGRES/download
mkdir -p $FOLDER_BACKUP
mkdir -p $FOLDER_POSTGRES/gz
mkdir -p $FOLDER_POSTGRES/alloydb
mkdir -p $FOLDER_POSTGRES/unload
mkdir -p $FOLDER_POSTGRES/tables

cp /home/*.* $FOLDER_POSTGRES/.
cp -f $KEY $FOLDER_POSTGRES/.
chmod 0400 $FOLDER_POSTGRES/key

# Creating a global parameters file
echo "$(date) : global parameters file"
echo "export REDSHIFT_IP=$REDSHIFT_IP" > $FOLDER_POSTGRES/parameters_cnx.sh
echo "export REDSHIFT_PORT=$REDSHIFT_PORT" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export REDSHIFT_USER=$REDSHIFT_USER" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export REDSHIFT_PASSWORD=$REDSHIFT_PASSWORD" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export ALLOYDB_IP=$ALLOYDB_IP" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export ALLOYDB_PORT=$ALLOYDB_PORT" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export ALLOYDB_USER=$ALLOYDB_USER" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export ALLOYDB_PASSWORD=$ALLOYDB_PASSWORD" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export DB=$DB" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export S3_BUCKET_BASE=$S3_BUCKET_BASE" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export GCS_BUCKET=$GCS_BUCKET" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export IAM_ROLE=$IAM_ROLE" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export FILEPARAMETERS=$FILEPARAMETERS" >> $FOLDER_POSTGRES/parameters_cnx.sh
echo "export FOLDER_REMOTO=$FOLDER_REMOTO" >> $FOLDER_POSTGRES/parameters_cnx.sh
chmod +x $FOLDER_POSTGRES/*.sh

echo "$(date) : send file parameters"
scp -o "StrictHostKeyChecking no" -i $KEY $FOLDER_POSTGRES/parameters_cnx.sh $USERREMOTO@$INSTANCEVPN:$FOLDER_REMOTO/$FILEPARAMETERS.sh

# SO Know of hosts access remoto by user Postgres and root
echo "$(date) : settings access"
chown -R postgres.postgres $FOLDER_POSTGRES
mkdir -p /var/lib/postgresql/.aws/
cp /home/credentials /var/lib/postgresql/.aws/credentials
chown -R postgres.postgres /var/lib/postgresql/*
chmod 600 /var/lib/postgresql/.aws/credentials

echo "$(date) : start service postgres"
cp -f /home/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf
chown -R postgres.postgres /etc/postgresql/16/main/pg_hba.conf
su postgres -c "/usr/lib/postgresql/16/bin/postgres -c config_file=/etc/postgresql/16/main/postgresql.conf" &>/dev/null &
sleep 10

echo "$(date) : create pg_dump REDSHIT"
ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "PGPASSWORD=$REDSHIFT_PASSWORD pg_dump -U $REDSHIFT_USER -h $REDSHIFT_IP -p $REDSHIFT_PORT --format=plain -s --no-synchronized-snapshots -f $FOLDER_REMOTO/$DB.sql $DB"
scp -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN:$FOLDER_REMOTO/$DB.sql $FOLDER_BACKUP/$DB.sql
echo "$(date) : ajustando pg_dump REDSHIT"
sed -i "s/DEFAULT \"identity\"([0-9]\+, 0, '1,1'::text) NOT NULL/ /g"  $FOLDER_BACKUP/$DB.sql
sed -i "s/DEFAULT default_identity([0-9]\+, 0, '1,1'::text) NOT NULL/ /g"  $FOLDER_BACKUP/$DB.sql
sed -i "s/getdate()/ now()/g" $FOLDER_BACKUP/$DB.sql
sed -i "s/CREATE CAST ([a-z]\+ AS binary varying)/-- /g" $FOLDER_BACKUP/$DB.sql
sed -i "s/CREATE CAST (binary varying AS/-- /g" $FOLDER_BACKUP/$DB.sql
sed -i "s/RETURNS \-/RETURNS void/g" $FOLDER_BACKUP/$DB.sql
sed -i "s/AS '-1:-1', /AS /g" $FOLDER_BACKUP/$DB.sql
sed -i "s/CREATE MATERIALIZED VIEW/; CREATE VIEW/g" $FOLDER_BACKUP/$DB.sql

echo "$(date) : create database local"
su postgres -c "createdb -h localhost -p 5432 -U postgres $DB"
su postgres -c "psql -h localhost -p 5432 -U postgres $DB < $FOLDER_BACKUP/$DB.sql"

echo "$(date) : create backup local"
su postgres -c "pg_dump -U postgres -h localhost -p 5432  --format=plain -s --no-synchronized-snapshots -f $FOLDER_BACKUP/$DB_local.sql $DB"

echo "$(date) : create backup alloydb"
export PGPASSWORD=$ALLOYDB_PASSWORD
createdb -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB

echo "$(date) : create schema temporal local"
su postgres -c "psql -h localhost -p 5432 -U postgres $DB < $FOLDER_POSTGRES/schema_temporal.sql"

echo "$(date) : restore data redshift to alloydb"
su postgres -c "psql -h localhost -p 5432 -U postgres $DB < $FOLDER_POSTGRES/restore_redshift_to_alloydb.sql"

ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "rm -f $FOLDER_REMOTO/$FILEPARAMETERS.sh"
echo "$(date) : end process restore"

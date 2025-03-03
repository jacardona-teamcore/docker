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
MAX=${14}
MAX_DUPLICATION=${15}
SCHEMAS=${16}
CUSTOM=${16}

DATETIME=$(date +"%Y%m%d%H%M%S")
FILEPARAMETERS="${DB}_${DATETIME}"
FOLDER_REMOTO="/home/ubuntu"
FOLDER_POSTGRES="/home/postgres"
FOLDER_BACKUP="$FOLDER_POSTGRES/backup"
USERREMOTO="ubuntu"
KEY="/home/vpn/key"
FILELOG=${DB}_${DATETIME}
OPTS_SCHEMA=""

cp $KEY /home/.
KEY="/home/key"
chmod 0400 $KEY

ls -lh /home/
ls -lh /home/aws
ls -lh /home/vpn

rm -rf $FOLDER_POSTGRES
mkdir -p $FOLDER_POSTGRES
echo "$(date) : Install postgres service" > ${FOLDER_POSTGRES}/${FILELOG}.log

sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
rm -f /etc/apt/trusted.gpg.d/postgresql.gpg
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
apt install -y postgresql-16 postgresql-contrib-16

echo "$(date) : Exists databases in alloydb" >> ${FOLDER_POSTGRES}/${FILELOG}.log
export PGPASSWORD=$ALLOYDB_PASSWORD
psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -lqt | cut -d \| -f 1 | grep "${DB} " | wc -l > ${FOLDER_POSTGRES}/database.count
COUNT=$(cat ${FOLDER_POSTGRES}/database.count);

if [[ "$COUNT" -eq 1  &&  "$SCHEMAS" == "NA" ]]; then
    echo "$(date) : La ${DB} existe en AlloyDB no se ejecuto el proceso " >> ${FOLDER_POSTGRES}/${FILELOG}.log
else

    if [ "$SCHEMAS" != "NA" ]; then 
        SCHEMAS=$(ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "PGPASSWORD=$REDSHIFT_PASSWORD psql -U $REDSHIFT_USER -h $REDSHIFT_IP -p $REDSHIFT_PORT -tAc \"select n.nspname from pg_catalog.pg_namespace n where n.nspname = '${SCHEMAS}' or n.nspname ~ '${SCHEMAS}_[0-9]' order by 1 desc limit 1\" $DB")
        DELETE=$(psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -tAc "select n.nspname from pg_catalog.pg_namespace n where n.nspname = '${CUSTOM}' or n.nspname ~ '${CUSTOM}_[0-9]' order by 1 asc limit 1" $DB)
    fi

    if [ -z ${SCHEMAS} ]; then
        echo "$(date) : Schema ${SCHEMAS} not found in redshift" >> ${FOLDER_POSTGRES}/${FILELOG}.log
    else
        echo "$(date) : Start configuration postgres" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        # Copy configuration file and access to postgres user
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
        echo "$(date) : global parameters file" >> ${FOLDER_POSTGRES}/${FILELOG}.log
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
        echo "export USERREMOTO=$USERREMOTO" >> $FOLDER_POSTGRES/parameters_cnx.sh
        echo "export INSTANCEVPN=$INSTANCEVPN" >> $FOLDER_POSTGRES/parameters_cnx.sh
        echo "export SCHEMAS=$SCHEMAS" >> $FOLDER_POSTGRES/parameters_cnx.sh
        chmod +x $FOLDER_POSTGRES/*.sh

        echo "$(date) : send file parameters" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        scp -o "StrictHostKeyChecking no" -i $KEY $FOLDER_POSTGRES/parameters_cnx.sh $USERREMOTO@$INSTANCEVPN:$FOLDER_REMOTO/$FILEPARAMETERS.sh

        # SO Know of hosts access remoto by user Postgres and root
        echo "$(date) : settings access" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        chown -R postgres.postgres $FOLDER_POSTGRES
        chown -R postgres:postgres $FOLDER_POSTGRES
        mkdir -p /var/lib/postgresql/.aws/
        cp -f /home/aws/credentials /var/lib/postgresql/.aws/credentials
        chown -R postgres.postgres /var/lib/postgresql/
        chown -R postgres:postgres /var/lib/postgresql/
        chmod 600 /var/lib/postgresql/.aws/credentials

        if [[ $MAX -ge 9 ]]; then
            PGCORE="12"
        elif [[ $MAX -ge 5 ]]; then
            PGCORE="8"
        else
            PGCORE=""
        fi

        echo "$(date) : start service postgres" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        cp -f /home/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf
        cp -f /home/postgresql${PGCORE}.conf /etc/postgresql/16/main/postgresql.conf
        chown -R postgres.postgres /etc/postgresql/16/main/*
        chown -R postgres:postgres /etc/postgresql/16/main/*
        su postgres -c "/usr/lib/postgresql/16/bin/postgres -c config_file=/etc/postgresql/16/main/postgresql.conf &>/dev/null &"
        sleep 10

        if [[ "$SCHEMAS" != "NA"  &&  "$COUNT" -eq 0 ]] ; then
            OPTS_SCHEMA="-n ${SCHEMAS} -n public -n dba_views"
        elif [ "$SCHEMAS" != "NA" ] ; then
            OPTS_SCHEMA="-n ${SCHEMAS} -n public"
        fi  

        echo "$(date) : create pg_dump REDSHIT $OPTS_SCHEMA" >> ${FOLDER_POSTGRES}/${FILELOG}.log

        ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "PGPASSWORD=$REDSHIFT_PASSWORD pg_dump -U $REDSHIFT_USER -h $REDSHIFT_IP -p $REDSHIFT_PORT ${OPTS_SCHEMA} --format=plain -s --no-synchronized-snapshots -f $FOLDER_REMOTO/$DB.sql $DB"
        scp -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN:$FOLDER_REMOTO/$DB.sql $FOLDER_BACKUP/$DB.sql
        echo "$(date) : ajustando pg_dump REDSHIT" >> ${FOLDER_POSTGRES}/${DB}.log
        sed -i "s/DEFAULT \"identity\"([0-9]\+, [0-9]\+, '1,1'::text) NOT NULL/ /g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/DEFAULT \"identity\"([0-9]\+, [0-9]\+, '1,1'::text)/ /g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/DEFAULT default_identity([0-9]\+, [0-9]\+, '1,1'::text) NOT NULL/ /g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/DEFAULT default_identity([0-9]\+, [0-9]\+, '1,1'::text)/ /g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/boolean DEFAULT 0/boolean DEFAULT false/g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/boolean DEFAULT 1/boolean DEFAULT true/g"  $FOLDER_BACKUP/$DB.sql
        sed -i "s/getdate()/ now()/g" $FOLDER_BACKUP/$DB.sql
        sed -i "s/CREATE CAST ([a-z]\+ AS binary varying)/-- /g" $FOLDER_BACKUP/$DB.sql
        sed -i "s/CREATE CAST (binary varying AS/-- /g" $FOLDER_BACKUP/$DB.sql
        sed -i "s/RETURNS \-/RETURNS void/g" $FOLDER_BACKUP/$DB.sql
        sed -i "s/AS '-1:-1', /AS /g" $FOLDER_BACKUP/$DB.sql
        sed -i "s/CREATE MATERIALIZED VIEW/; CREATE VIEW/g" $FOLDER_BACKUP/$DB.sql

        gsutil cp ${FOLDER_BACKUP}/${DB}.sql ${GCS_BUCKET}/${DB}/${DATETIME}/${DB}.sql
        echo "$(date) : create database local" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        su postgres -c "createdb -h localhost -p 5432 -U postgres $DB"
        su postgres -c "psql -h localhost -p 5432 -U postgres $DB < ${FOLDER_BACKUP}/${DB}.sql"

        echo "$(date) : delete constraint" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        su postgres -c "psql -h localhost -p 5432 -U postgres $DB < $FOLDER_POSTGRES/schema_constraint.sql"

        echo "$(date) : create backup local" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        if [[ "$SCHEMAS" != "NA"  &&  "$COUNT" -eq 0 ]] ; then
            OPTS_SCHEMA=""
        elif [ "$SCHEMAS" != "NA" ] ; then
            OPTS_SCHEMA="-n ${SCHEMAS}"
        fi  

        su postgres -c "pg_dump -U postgres -h localhost -p 5432 ${OPTS_SCHEMA} --format=plain -s -f $FOLDER_BACKUP/${DB}_local.sql $DB"

        gsutil cp ${FOLDER_BACKUP}/${DB}_local.sql ${GCS_BUCKET}/${DB}/${DATETIME}/${DB}_local.sql

        echo "$(date) : create schema temporal local" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        su postgres -c "psql -h localhost -p 5432 -U postgres $DB < $FOLDER_POSTGRES/schema_temporal.sql"

        echo "$(date) : Change schema temporal of load tables" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        su postgres -c "psql -h localhost -p 5432 -U postgres -c \"select * from public.fnc_set_load_tables(${MAX_DUPLICATION})\" $DB"

        export PGPASSWORD=$ALLOYDB_PASSWORD

        if [[ "$SCHEMAS" == "NA"  ||  "$COUNT" -eq 0 ]] ; then
            echo "$(date) : create database in alloydb" >> ${FOLDER_POSTGRES}/${FILELOG}.log
            createdb -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB
        elif [ "$SCHEMAS" != "NA" ] ; then
            echo "$(date) : delete schema ${SCHEMAS}" >> ${FOLDER_POSTGRES}/${FILELOG}.log
            psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -c "DROP SCHEMA IF EXISTS ${SCHEMAS} CASCADE" $DB
        fi

        echo "$(date) : restore backup in alloydb" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB < $FOLDER_BACKUP/${DB}_local.sql

        echo "$(date) : restore data redshift to alloydb" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        COMMAND="psql -h localhost -p 5432 -U postgres -tAc "
        SQL="SELECT COUNT(1) FROM temporal.tables_load WHERE estado="
        COUNT=$(su postgres -c "$COMMAND \"${SQL}'PENDIENTE'\" ${DB}")
        NEXT=1

        if [ "$COUNT" -gt 0 ]; then

            while [ $COUNT -gt 0 ]; do
                COUNT=$(su postgres -c "$COMMAND \"${SQL}'PROCESANDO'\" ${DB}")
                
                if [ "$COUNT" -eq 3 ]; then
                    sleep 2
                    COUNT=$(su postgres -c "$COMMAND \"${SQL}'PROCESANDO'\" ${DB}")
                fi

                while [ $COUNT -lt $MAX ]
                do
                    # process next table process
                    ID=$(su postgres -c "$COMMAND \"SELECT * FROM fnc_get_load_table()\" ${DB}")

                    if [ "${ID}" -gt 0 ]; then
                        # execute process load
                        $FOLDER_POSTGRES/restore_cycle_tables.sh  "${ID}" "${BD}" "${DB}_${ID}" "${FOLDER_POSTGRES}" &
                    fi
                    
                    COUNT=$((COUNT + NEXT))
                done

                COUNT=$(su postgres -c "$COMMAND \"${SQL}'PENDIENTE'\" ${DB}")
            done

            echo "$(date) : start validate load" >> ${FOLDER_POSTGRES}/${FILELOG}.log
            COUNT=$(su postgres -c "$COMMAND \"${SQL}'PROCESANDO'\" ${DB}")
            if [ "$COUNT" -gt 0 ]; then
                while [ $COUNT -gt 0 ]; do
                    sleep 10
                    COUNT=$(su postgres -c "$COMMAND \"${SQL}'PROCESANDO'\" ${DB}")
                done
            fi
            echo "$(date) : end validate load" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        fi

        echo "$(date) : update migration sql pgsql" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER $DB < /home/pgsql_migration.sql

        if [ "$SCHEMAS" != "NA" ]; then 
            COUNT=$(su postgres -c "$COMMAND \"${SQL}'ERROR'\" ${DB}")

            if [ "$COUNT" -eq 0 ]; then
                export PGPASSWORD="$ALLOYDB_PASSWORD"

                COUNT=$(psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -tAc "select count(1) from pg_catalog.pg_namespace n where n.nspname = '${CUSTOM}' or n.nspname ~ '${CUSTOM}_[0-9]' " $DB)

                if [ "$COUNT" -gt 1 ]; then
                    if [ -z ${DELETE} ]; then
                        echo "$(date) : custom ${CUSTOM} not found in history schemas AlloydDB" >> ${FOLDER_POSTGRES}/${FILELOG}.log
                    elif [ "${SCHEMAS}" != "${DELETE}" ]; then
                        echo "$(date) : custom ${CUSTOM} start delete schema ${DELETE}" >> ${FOLDER_POSTGRES}/${FILELOG}.log
                        psql -h $ALLOYDB_IP -p $ALLOYDB_PORT -U $ALLOYDB_USER -c "drop schema ${DELETE} cascade" $DB
                    fi
                else
                    echo "$(date) : the number schemas of ${CUSTOM} in databases AlloydDB, is minor to 1, not delete schema" >> ${FOLDER_POSTGRES}/${FILELOG}.log
                fi
            fi
        fi    

        ssh -o "StrictHostKeyChecking no" -i $KEY $USERREMOTO@$INSTANCEVPN "rm -f $FOLDER_REMOTO/$FILEPARAMETERS.sh"

        echo "$(date) : consult status tables" >> ${FOLDER_POSTGRES}/${FILELOG}.log
        su postgres -c "psql -h localhost -p 5432 -U postgres -c \"\\copy (select * from temporal.tables_load) TO '${FOLDER_POSTGRES}/${FILELOG}.tables' WITH CSV HEADER;\" $DB"

        gsutil cp ${FOLDER_POSTGRES}/${FILELOG}.log ${GCS_BUCKET}/${DB}/${DATETIME}/${FILELOG}.log
    fi
fi

echo "$(date) : end process restore" >> ${FOLDER_POSTGRES}/${FILELOG}.log
gsutil cp ${FOLDER_POSTGRES}/${FILELOG}.tables ${GCS_BUCKET}/${DB}/${DATETIME}/${FILELOG}.tables

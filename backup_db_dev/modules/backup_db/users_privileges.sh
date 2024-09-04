#!/bin/bash

NEW_DB=$1
NEW_DB_USER=$2
NEW_DB_USER_PASSWORD=$3
PG_BOUNCER_PASSWORD=$4
cd "$HOME"
echo "start user db privileges at $(date)"


psql -c "CREATE ROLE $NEW_DB_USER LOGIN PASSWORD '${NEW_DB_USER_PASSWORD}';"

psql -c "CREATE ROLE tc2;"
psql -c "GRANT tc2 TO $NEW_DB_USER;"
psql -c "GRANT CONNECT ON DATABASE $NEW_DB TO tc2;"
psql -c "GRANT CONNECT ON DATABASE ${NEW_DB}_cubo TO tc2;"
psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tc2;" -d "$NEW_DB"
psql -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tc2;" -d "$NEW_DB"
psql -c "GRANT postgres TO $NEW_DB_USER;" -d "$NEW_DB"

psql -c "CREATE ROLE pgbouncer WITH LOGIN PASSWORD '${PG_BOUNCER_PASSWORD}';"
#psql -c "CREATE DATABASE pgbouncer;"
psql -c "CREATE SCHEMA pgbouncer AUTHORIZATION pgbouncer;" -d "$NEW_DB"

#pgbouncer auth_function
IFS='' read -r -d '' FNC <<'EOF'
CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_usename TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE WARNING 'PgBouncer auth request: %', p_usename;

    RETURN QUERY
    SELECT usename::TEXT, passwd::TEXT FROM pg_catalog.pg_shadow
     WHERE usename = p_usename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
EOF

CMD=$(echo "$FNC" | tr -s '\n' ' ')

psql -c "$CMD" -d "$NEW_DB"

psql -c "REVOKE ALL ON FUNCTION pgbouncer.get_auth(p_usename TEXT) FROM PUBLIC;" -d "$NEW_DB"
psql -c "GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(p_usename TEXT) TO pgbouncer;" -d "$NEW_DB"

#ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO tc2;

#psql -c "GRANT USAGE ON SCHEMA public TO tc2;"
#--GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON ALL TABLES  IN SCHEMA public TO tc2;
#--GRANT USAGE  ON ALL SEQUENCES IN SCHEMA public TO tc2;  -- if you also granted INSERT
#psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tc2;"
#psql -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tc2;"

echo "end user db privileges at $(date)"

#!/bin/bash

NEW_DB=$1
NEW_DB_USER_PASSWORD=$2
PG_BOUNCER_PASSWORD=$3
NEW_DB_USER=${NEW_DB//_/.}
cd "$HOME"

echo "$(date) : start user db privileges"
/usr/bin/psql -c "CREATE ROLE $NEW_DB_USER LOGIN PASSWORD '${NEW_DB_USER_PASSWORD}';"
/usr/bin/psql -c "CREATE ROLE tc2;"
/usr/bin/psql -c "GRANT tc2 TO $NEW_DB_USER;"
/usr/bin/psql -c "GRANT CONNECT ON DATABASE $NEW_DB TO tc2;"
/usr/bin/psql -c "GRANT CONNECT ON DATABASE ${NEW_DB}_cubo TO tc2;"
/usr/bin/psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO tc2;" -d "$NEW_DB"
/usr/bin/psql -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO tc2;" -d "$NEW_DB"
/usr/bin/psql -c "GRANT postgres TO $NEW_DB_USER;" -d "$NEW_DB"

/usr/bin/psql -c "CREATE ROLE pgbouncer WITH LOGIN PASSWORD '${PG_BOUNCER_PASSWORD}';"
/usr/bin/psql -c "CREATE SCHEMA pgbouncer AUTHORIZATION pgbouncer;" -d "$NEW_DB"

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

/usr/bin/psql -c "$CMD" -d "$NEW_DB"
/usr/bin/psql -c "REVOKE ALL ON FUNCTION pgbouncer.get_auth(p_usename TEXT) FROM PUBLIC;" -d "$NEW_DB"
/usr/bin/psql -c "GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(p_usename TEXT) TO pgbouncer;" -d "$NEW_DB"

echo "end user db privileges at $(date)"

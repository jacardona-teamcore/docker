#!/bin/bash
VERSION=16

echo "$(date) : started service postgres"
su postgres -c "/usr/lib/postgresql/$VERSION/bin/postgres -c config_file=/etc/postgresql/$VERSION/main/postgresql.conf" &>/dev/null &
sleep 10

supervisord -n
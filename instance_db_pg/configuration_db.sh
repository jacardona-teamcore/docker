
FILE=$1
VERSION=16

systemctl stop postgresql
sleep 5

rm -f /etc/postgresql/$VERSION/main/postgresql.conf
cp /home/configurtions/postgresql.conf >> /etc/postgresql/$VERSION/main/postgresql.conf
cp /home/configurtions/$FILE.conf >> /etc/postgresql/$VERSION/main/postgresql.conf

systemctl start postgresql
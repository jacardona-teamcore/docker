VERSION=$1
DB=$2
FOLDERUSER=$3
BUCKET=$4
FOLDERRESTORE=$3/restore

rm -rf $FOLDERRESTORE

sudo pkill -u postgres

echo "$(date) : download files of bucket"
mkdir -p $FOLDERRESTORE
cd $FOLDERRESTORE
gcloud storage cp $BUCKET/$DB $FOLDERRESTORE --recursive

echo "$(date) : start descompress lz4"
for file in $(find "$FOLDERRESTORE/$DB" -name "*.lz4"); do
  echo "Descompress : $file"
  /usr/bin/lz4 -d "$file" 
done

echo "$(date) : create folder lz4"
mkdir lz4
mv $FOLDERRESTORE/$DB/*.lz4 lz4/.
cd $FOLDERRESTORE/$DB/
echo "$(date) : concat file tar"
cat * > $DB.tar

echo "$(date) : descompress tar"
tar -xf $DB.tar

sudo systemctl stop postgresql
sleep 15

echo "$(date) : restore database"
sudo rm -rf /etc/postgresql/$VERSION/main
sudo mv latest_backup /etc/postgresql/$VERSION/main

sudo rm -f /etc/postgresql/$VERSION/main/pg_hba.conf 
sudo cp $FOLDERUSER/pg_hba.conf /etc/postgresql/$VERSION/main/.
sudo cp $FOLDERUSER/postgresql.conf /etc/postgresql/$VERSION/main/postgresql.conf
sudo mkdir /etc/postgresql/$VERSION/main/conf.d
sudo chown -R postgres:postgres /etc/postgresql/$VERSION/main/
sudo chmod 700 -R /etc/postgresql/$VERSION/main/

cd /var/lib/postgresql/
sudo rm -rf $VERSION
sudo ln -s /etc/postgresql/$VERSION/ $VERSION
sudo chown postgres.postgres $VERSION

echo "$(date) : start postgres"
sudo systemctl start postgresql
sleep 10

cd ~
sudo rm -rf $FOLDERRESTORE
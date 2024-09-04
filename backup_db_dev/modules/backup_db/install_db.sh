#!/bin/bash
PG_VERSION=$1
sudo NEEDRESTART_MODE=a apt update
sudo NEEDRESTART_MODE=a apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg wget lsb-release
sudo NEEDRESTART_MODE=a apt install -y git
sudo NEEDRESTART_MODE=a snap install google-cloud-cli --classic
sudo NEEDRESTART_MODE=a apt install -y zip
sudo NEEDRESTART_MODE=a apt install -y pip
sudo NEEDRESTART_MODE=a apt install -y liblz4-tool
sudo NEEDRESTART_MODE=a apt install -y pigz
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo NEEDRESTART_MODE=a apt update
sudo NEEDRESTART_MODE=a apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo chmod 666 /var/run/docker.sock
sudo ufw allow 5432
sudo NEEDRESTART_MODE=a apt install -y postgresql postgresql-contrib

sleep 15
sudo systemctl stop postgresql
sleep 15

sudo mv -f "$HOME"/postgresql.conf /etc/postgresql/"$PG_VERSION"/main/postgresql.conf
sudo chown postgres:postgres /etc/postgresql/"$PG_VERSION"/main/postgresql.conf

sudo mv -f "$HOME"/pg_hba.conf /etc/postgresql/"$PG_VERSION"/main/pg_hba.conf
sudo chown postgres:postgres /etc/postgresql/"$PG_VERSION"/main/pg_hba.conf

#sudo systemctl status postgresql
#sleep 10
sudo mkdir -p /mnt/disks/ssd-array/var/lib
#sudo chown postgres:postgres /mnt/disks/ssd-array/var/lib/postgresql
sudo rsync -av /var/lib/postgresql /mnt/disks/ssd-array/var/lib
sudo chmod 700 /mnt/disks/ssd-array/var/lib/postgresql/14/main
sudo systemctl restart postgresql
sleep 10
#sudo systemctl status postgresql
sudo pg_lsclusters
docker run -d -v "$HOME"/sa.json:/config -p 127.0.0.1:6432:5432 gcr.io/cloudsql-docker/gce-proxy:1.33.0 /cloud_sql_proxy -instances="$SQLCLOUD_CONNECTION"=tcp:0.0.0.0:5432 -credential_file=/config
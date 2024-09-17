VERSION=$1
FOLDERUSER=$2
sudo NEEDRESTART_MODE=a apt update
sudo NEEDRESTART_MODE=a apt install -y gnupg2 wget nano
sudo NEEDRESTART_MODE=a apt install -y software-properties-common lsb-release
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
sudo NEEDRESTART_MODE=a apt install -y git
sudo snap install google-cloud-cli --classic
sudo NEEDRESTART_MODE=a apt install -y zip
sudo NEEDRESTART_MODE=a apt install -y pip
sudo NEEDRESTART_MODE=a apt install -y liblz4-tool
sudo NEEDRESTART_MODE=a apt install -y pigz

sudo ufw allow 5432
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
sudo echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update 
sudo apt-get install -y google-cloud-cli

sudo NEEDRESTART_MODE=a apt install -y postgresql-16 postgresql-contrib-16

cd /home
sudo curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.13.0/cloud-sql-proxy.linux.amd64
sudo chmod +x cloud-sql-proxy

sudo systemctl stop postgresql
sleep 5

sudo rm -f /etc/postgresql/$VERSION/main/pg_hba.conf
sudo cp $FOLDERUSER/pg_hba.conf /etc/postgresql/$VERSION/main/pg_hba.conf
sudo cat $FOLDERUSER/postgresql_machine.conf >> /etc/postgresql/$VERSION/main/postgresql.conf
sudo cp /etc/postgresql/$VERSION/main/postgresql.conf $FOLDERUSER/postgresql.conf
sudo chown postgres:postgres /etc/postgresql/$VERSION/main/*.*

sudo systemctl start postgresql
sleep 10
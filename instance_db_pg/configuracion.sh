NEEDRESTART_MODE=a apt update
apt-get update
apt-get install -y apt-transport-https ca-certificates gnupg curl
apt-get install -y software-properties-common
NEEDRESTART_MODE=a apt install -y gnupg2 wget nano
NEEDRESTART_MODE=a apt install -y software-properties-common lsb-release
NEEDRESTART_MODE=a apt install -y git
snap install google-cloud-cli --classic
NEEDRESTART_MODE=a apt install -y zip
NEEDRESTART_MODE=a apt install -y pip
NEEDRESTART_MODE=a apt install -y liblz4-tool
NEEDRESTART_MODE=a apt install -y pigz openssh-client bash

ufw allow 5432
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update 
apt-get install -y google-cloud-cli

wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
NEEDRESTART_MODE=a update
apt-get install terraform
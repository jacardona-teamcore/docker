#!/bin/bash
NEEDRESTART_MODE=a apt update
NEEDRESTART_MODE=a apt install -y gnupg2 wget nano
NEEDRESTART_MODE=a apt install -y software-properties-common lsb-release
apt-get install -y apt-transport-https ca-certificates gnupg curl
NEEDRESTART_MODE=a apt install -y git
snap install google-cloud-cli --classic
NEEDRESTART_MODE=a apt install -y zip
NEEDRESTART_MODE=a apt install -y unzip
NEEDRESTART_MODE=a apt install -y pip
NEEDRESTART_MODE=a apt install -y liblz4-tool
NEEDRESTART_MODE=a apt install -y pigz

ufw allow 5432
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update 
apt-get install -y google-cloud-cli

cd /home
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

chmod +x /home/*.sh

sudo NEEDRESTART_MODE=a apt update
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl
sudo apt-get install -y software-properties-common
sudo NEEDRESTART_MODE=a apt install -y gnupg2 wget nano
sudo NEEDRESTART_MODE=a apt install -y software-properties-common lsb-release
sudo NEEDRESTART_MODE=a apt install -y git
sudo snap install google-cloud-cli --classic
sudo NEEDRESTART_MODE=a apt install -y zip
sudo NEEDRESTART_MODE=a apt install -y pip
sudo NEEDRESTART_MODE=a apt install -y liblz4-tool
sudo NEEDRESTART_MODE=a apt install -y pigz openssh-client bash

sudo ufw allow 5432
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg

sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
sudo echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
sudo apt-get update 
sudo apt-get install -y google-cloud-cli

sudo wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

sudo echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo NEEDRESTART_MODE=a update
sudo apt-get install terraform
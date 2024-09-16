
apt update
apt install -y software-properties-common  wget lsb-release
apt-get install -y apt-transport-https ca-certificates gnupg curl
apt install -y git
snap install google-cloud-cli --classic
apt install -y zip
apt install -y pip
apt install -y liblz4-tool
apt install -y pigz
mkdir -p /etc/apt/keyrings
ufw allow 5432

curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update && apt-get install -y google-cloud-cli

cd /home
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.13.0/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy
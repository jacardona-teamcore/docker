#!/bin/sh

echo "setting keys ..."
eval "$(ssh-agent -s)"
ssh-add /app/.ssh/id_rsa
BUCKET_STATUS=$1
VARIABLES=$2
FOLDERTERRAFORM="/app/terraform"

echo "$(date) : delete files"
rm -f $FOLDERTERRAFORM/terraform.tfvars
rm -f $FOLDERTERRAFORM/backend.config

echo "$(date) : file terraform.tfvars"
for LINE in $(echo "$VARIABLES" | tr ';' '\n'); do
    echo "$(date) : $LINE"
    echo $LINE >> $FOLDERTERRAFORM/terraform.tfvars
done

echo "$(date) : file backend.config"
val1='bucket="'
val2='"'
complete="$val1$BUCKET_STATUS$val2"
echo "$complete" > $FOLDERTERRAFORM/backend.config

echo "$(date) : service account"
gcloud auth list

cd $FOLDERTERRAFORM
echo "$(date) : terraform init"
terraform init -reconfigure -backend-config="$FOLDERTERRAFORM/backend.config"
echo "$(date) : terraform plan"
terraform plan -var-file="$FOLDERTERRAFORM/terraform.tfvars"
echo "$(date) : terraform apply"
terraform apply -var-file="$FOLDERTERRAFORM/terraform.tfvars" -auto-approve
sleep 1200

echo "$(date) : end restore database"
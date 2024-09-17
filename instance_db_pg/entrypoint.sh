#!/bin/sh
sleep 3600
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
IFS=';' read -ra LINES <<< $VARIABLES
for LINE in "${LINES[@]}"; do
    echo "$(date) : $LINE"
    echo $LINE >> $FOLDERTERRAFORM/terraform.tfvars
done

echo "$(date) : file backend.config"
echo 'bucket="$BUCKET_STATUS"' > $FOLDERTERRAFORM/backend.config

gsutil rm gs://$BUCKET_STATUS/tc_arch360_restore/default.tfstate

cd $FOLDERTERRAFORM
echo "$(date) : terraform init"
terraform init -backend-config="$FOLDERTERRAFORM/backend.config"
echo "$(date) : terraform plan"
terraform plan -var-file="$FOLDERTERRAFORM/terraform.tfvars"
echo "$(date) : terraform apply"
terraform apply -var-file="$FOLDERTERRAFORM/terraform.tfvars" -auto-approve
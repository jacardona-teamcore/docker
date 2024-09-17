#!/bin/sh
echo "setting keys ..."
eval "$(ssh-agent -s)"
ssh-add /app/.ssh/id_rsa
BUCKET_STATUS=$1
VARIABLES=$2
FOLDERTERRAFORM="/app/terraform"

rm -f $FOLDERTERRAFORM/terraform.tfvars
rm -f $FOLDERTERRAFORM/backend.config

IFS=';' read -ra LINES <<< $VARIABLES
for LINE in "${LINES[@]}"; do 
    echo $LINE >> $FOLDERTERRAFORM/terraform.tfvars
done

echo 'bucket="$BUCKET_STATUS"' > $FOLDERTERRAFORM/backend.config

gsutil rm gs://$BUCKET_STATUS/tc_arch360_restore/default.tfstate

cd $FOLDERTERRAFORM
terraform init -backend-config="$FOLDERTERRAFORM/backend.config"
terraform plan -var-file="$FOLDERTERRAFORM/terraform.tfvars"
terraform apply -var-file="$FOLDERTERRAFORM/terraform.tfvars" -auto-approve
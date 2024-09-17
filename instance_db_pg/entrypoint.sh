#!/bin/sh
echo "setting keys ..."
eval "$(ssh-agent -s)"
ssh-add /app/.ssh/id_rsa
ARGUMENTS=$1
FOLDERTERRAFORM="/app/terraform"
rm -f $FOLDERTERRAFORM/terraform_example.tfvars

IFS=';' read -ra LINES <<< $ARGUMENTS
for LINE in "${LINES[@]}"; do 
    echo $LINE >> $FOLDERTERRAFORM/terraform_example.tfvars
done

cd $FOLDERTERRAFORM
terraform init
terraform plan
terraform apply -auto-approve
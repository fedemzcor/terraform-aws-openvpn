#!/bin/bash
if [ $1 = "create" ]
then

    terraform init -backend-config="config/s3.config"
    terraform plan -var-file="inputs.tfvars" -out="plan/create"
    terraform apply "plan/create"

elif [ $1 = "destroy" ]
then
    terraform init -backend-config="config/s3.config"
    terraform plan -destroy -var-file="inputs.tfvars" -out="plan/destroy"
    terraform apply "plan/destroy"

fi
#!/bin/bash

# Uncomment to login
#az login

deploymentName='ExampleDeployment'$(date +"%d-%b-%Y")

echo $deploymentName

rg="my-demo-rg"

az group create --name $rg --location "Central US"

az deployment group create \
    --name $deploymentName \
    --resource-group my-demo-rg \
    --template-file azuredeploy.json

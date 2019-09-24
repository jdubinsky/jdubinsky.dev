#!/bin/bash

pushd src
echo "Installing dev packages..."
mkdir build
npm install

# build js
echo "Compiling..."
npx tsc

# install dependencies (prod only)
echo "Copying files..."
cp package*.json build/
cp index.html build/

pushd build
echo "Installing prod packages..."
npm install --only=prod
popd

popd

# deploy new lambda zip

pushd infra
echo "Deploying to AWS..."
terraform init
# TODO: pull state from S3
# TODO: check that terraform plan output is only lambda
terraform plan -input=false -state=terraform.tfstate
# terraform apply -input=false -state=terraform.tfstate
# TODO: push state to S3
popd

echo "Done!"
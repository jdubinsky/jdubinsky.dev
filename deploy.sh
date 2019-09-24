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
# TODO: check that terraform plan output is only lambda
# and fail if other infra changes
terraform plan -input=false
terraform apply -input=false
popd

echo "Done!"
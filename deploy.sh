#!/bin/bash

pushd src

# build js
echo "Compiling..."
npx tsc

# install dependencies (prod only)
echo "Copying files..."
cp package*.json build/
cp index.html build/

pushd build
echo "Installing packages..."
npm install --only=prod
popd

popd

# deploy new lambda zip

pushd infra
echo "Deploying to AWS..."
# TODO: check that terraform plan output is only lambda
# terraform apply -input=false
terraform plan -input=false
popd

echo "Done!"
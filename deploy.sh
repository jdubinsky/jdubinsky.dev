#!/bin/bash

pushd src
echo "Installing dev packages..."
pwd
npm install

# build js
echo "Compiling..."
pwd
npx tsc

# install dependencies (prod only)
echo "Copying files..."
pwd
ls
cp package*.json build/
cp index.html build/

pushd build
pwd
echo "Installing prod packages..."
npm install --only=prod
ls
popd

popd

# deploy new lambda zip

pushd infra
pwd
ls
echo "Deploying to AWS..."
# TODO: check that terraform plan output is only lambda
# terraform apply -input=false
terraform plan -input=false
popd

echo "Done!"
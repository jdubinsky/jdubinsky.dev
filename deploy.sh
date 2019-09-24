#!/bin/bash

pushd src

# build js
npx tsc

# install dependencies (prod only)
cp package*.json build/
cp index.html build/

pushd build
npm install --only=prod
popd

popd

# deploy new lambda zip

pushd infra
# TODO: check that terraform plan output is only lambda
terraform apply -input=false
popd
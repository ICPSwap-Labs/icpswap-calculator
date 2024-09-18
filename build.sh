#!/bin/bash

rm -rf .dfx

cp -R ./dfx.json ./dfx_temp.json

echo "==> build ..."

cat <<< $(jq '.canisters={
  SwapCalculator: {
    "main": "./src/SwapCalculator.mo",
    "type": "motoko"
  }
}' dfx.json) > dfx.json
dfx start --background

dfx canister create --all
dfx build --all
dfx stop
rm ./dfx.json
cp -R ./dfx_temp.json ./dfx.json
rm ./dfx_temp.json

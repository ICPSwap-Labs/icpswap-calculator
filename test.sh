#!/bin/bash
# set -e
# clear
dfx stop
rm -rf .dfx
mv dfx.json dfx.json.bak
cat > dfx.json <<- EOF
{
  "canisters": {
    "SwapCalculator": {
      "main": "./src/SwapCalculator.mo",
      "type": "motoko"
    }
  },
  "defaults": { "build": { "packtool": "vessel sources" } }, "networks": { "local": { "bind": "127.0.0.1:8000", "type": "ephemeral" } }, "version": 1
}
EOF

dfx start --clean --background
echo "-=========== create all"
dfx canister create --all
echo "-=========== build all"
dfx build
echo

PRINCIPAL="$(dfx identity get-principal)"
WALLET="$(dfx identity get-wallet)"

echo "==> Install canisters"
echo
echo "==> install SwapCalculator"
dfx canister install SwapCalculator

dfx stop
mv dfx.json.bak dfx.json
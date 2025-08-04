#!/bin/bash
set -e
# clear

# --------- Deploy Local Canister ---------
mv dfx.json dfx.json.bak

cat > dfx.json <<- EOF
{
  "canisters": {
    "SwapCalculator": {
      "main": "./src/SwapCalculator.mo",
      "type": "motoko"
    },
    "SwapPool": {
      "main": ".vessel/icpswap-v3-service/v3.6.2/src/SwapPool.mo",
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
echo "==> Install canisters"
echo
echo "==> install SwapCalculator"
dfx canister install SwapCalculator

# User input canister IDs
echo "Please enter canister IDs (multiple IDs separated by commas, e.g.: abc123,def456,ghi789):"
read -r canister_ids_input

# Convert input string to one ID per line format
canister_ids=$(echo "$canister_ids_input" | tr ',' '\n')

# Iterate through each canister ID
while IFS= read -r canister_id; do
    # Skip empty lines
    if [ -z "$canister_id" ]; then
        continue
    fi
    
    echo "Processing canister: $canister_id"

    # Immediately set setAvailable(false) to ensure data is not interfered with
    echo "--------- Set Available False ---------"
    dfx canister --network=ic call "$canister_id" setAvailable '(false)'
    
    # Wait 3 seconds for state change to take effect
    echo "Waiting 3 seconds for state change to take effect..."
    sleep 3

    metadata_result=$(dfx canister --network=ic call "$canister_id" metadata --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)
    sqrtPriceX96=$(echo "$metadata_result" | jq -r '.ok.sqrtPriceX96' | tr -d '_')
    currentTick=$(echo $result | jq -r '.ok.tick' | tr -d '_')
    echo "sqrtPriceX96: $sqrtPriceX96"


    echo "--------- All User Positions ---------"
    result=$(dfx canister --network=ic call "$canister_id" getUserPositions "(0, 1000)" --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

    computedPositionTotalAmount0=0
    computedPositionTotalAmount1=0

    content=$(echo "$result" | jq -c '.ok.content[]')
    totalItems=$(echo "$result" | jq '.ok.content | length')
    currentIndex=0

    # Initialize ids array
    ids_array=()
    current_ids=""

    for item in $content; do
        currentIndex=$((currentIndex + 1))
        echo "Processing item $currentIndex/$totalItems"

        id=$(echo $item | jq -r '.id' | tr -d '_')

        # If current_ids is not empty, add semicolon
        if [ -n "$current_ids" ]; then
            current_ids="${current_ids};"
        fi
        current_ids="${current_ids}${id}"

        # If ids length exceeds 50, store in array and reset. This solves the problem that batchRefreshIncome cannot query too many ids at once
        if [ $(echo "$current_ids" | tr -cd ';' | wc -c) -ge 50 ]; then
            ids_array+=("$current_ids")
            current_ids=""
        fi

        liquidity=$(echo $item | jq -r '.liquidity' | tr -d '_')
        tickLower=$(echo $item | jq -r '.tickLower' | tr -d '_')
        tickUpper=$(echo $item | jq -r '.tickUpper' | tr -d '_')

        calc_result=$(dfx canister call SwapCalculator getTokenAmountByLiquidity "($sqrtPriceX96, $tickLower, $tickUpper, $liquidity)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json 2>&1)

        # Extract amount values
        amount0=$(echo "$calc_result" | jq -r '.amount0' | tr -d '_')
        amount1=$(echo "$calc_result" | jq -r '.amount1' | tr -d '_')

        # Add to totals
        computedPositionTotalAmount0=$(echo "$computedPositionTotalAmount0 + $amount0" | bc -l)
        computedPositionTotalAmount1=$(echo "$computedPositionTotalAmount1 + $amount1" | bc -l)
    done

    # Store the last ids
    if [ -n "$current_ids" ]; then
        ids_array+=("$current_ids")
    fi

    echo "ids_array: ${ids_array[@]}"

    echo "--------- Batch Refresh Income ---------"
    # Loop through ids_array
    for ids in "${ids_array[@]}"; do
        result=$(dfx canister --network=ic call "$canister_id" batchRefreshIncome "(vec {${ids}})" --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)
    
        positionTotalFees0=$(echo "$result" | jq -c '.ok.totalTokensOwed0' | tr -d '_')
        positionTotalFees1=$(echo "$result" | jq -c '.ok.totalTokensOwed1' | tr -d '_')
        positionTotalFees0=$(echo "$positionTotalFees0" | bc -l)
        positionTotalFees1=$(echo "$positionTotalFees1" | bc -l)

        computedPositionTotalFees0=$(echo "scale=0; $positionTotalFees0 / 0.8" | bc -l)
        computedPositionTotalFees1=$(echo "scale=0; $positionTotalFees1 / 0.8" | bc -l)

        # Add to totals
        computedPositionTotalAmount0=$(echo "$computedPositionTotalAmount0 + $computedPositionTotalFees0" | bc -l)
        computedPositionTotalAmount1=$(echo "$computedPositionTotalAmount1 + $computedPositionTotalFees1" | bc -l)
    done

    result=$(dfx canister --network=ic call "$canister_id" getTokenAmountState --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

    swapFee0Repurchase=$(echo $result | jq -r '.ok.swapFee0Repurchase' | tr -d '_')
    swapFee1Repurchase=$(echo $result | jq -r '.ok.swapFee1Repurchase' | tr -d '_')

    computedPositionTotalAmount0=$(echo "$computedPositionTotalAmount0 + $swapFee0Repurchase" | bc -l)
    computedPositionTotalAmount1=$(echo "$computedPositionTotalAmount1 + $swapFee1Repurchase" | bc -l)

    echo "computedPositionTotalAmount0: $computedPositionTotalAmount0"
    echo "computedPositionTotalAmount1: $computedPositionTotalAmount1"

    echo "--------- Reset Token Amount State ---------"
    dfx canister --network=ic call "$canister_id" setTokenAmountState "($computedPositionTotalAmount0, $computedPositionTotalAmount1)"

    dfx canister --network=ic call "$canister_id" setAvailable '(true)'

done <<< "$canister_ids"

dfx stop
mv dfx.json.bak dfx.json
#!/bin/bash

# --------- Set Onchain Canisters ---------
poolId=""

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

echo "--------- SwapPool Metadata ---------"
result=$(dfx canister --network=ic call $poolId metadata --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

sqrtPriceX96=$(echo $result | jq -r '.ok.sqrtPriceX96')
# currentTick=$(echo $result | jq -r '.ok.tick')

echo "--------- Token Balance ---------"
result=$(dfx canister --network=ic call $poolId getTokenBalance --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

token0Balance=$(echo $result | jq -r '.token0' | tr -d '_')
token1Balance=$(echo $result | jq -r '.token1' | tr -d '_')

echo "--------- Token Amount State ---------"
result=$(dfx canister --network=ic call $poolId getTokenAmountState --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

swapFee0Repurchase=$(echo $result | jq -r '.ok.swapFee0Repurchase' | tr -d '_')
swapFee1Repurchase=$(echo $result | jq -r '.ok.swapFee1Repurchase' | tr -d '_')
positionToken0Amount=$(echo $result | jq -r '.ok.token0Amount' | tr -d '_')
positionToken1Amount=$(echo $result | jq -r '.ok.token1Amount' | tr -d '_')

echo "--------- User Unused Token Balance ---------"
result=$(dfx canister --network=ic call $poolId allTokenBalance "(0, 1000)" --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

unusedToken0Balance=$(echo "$result" | jq -r '.ok.content[]."1".balance0 | gsub("_"; "") | tonumber' | awk '{sum += $1} END {print sum}')
unusedToken1Balance=$(echo "$result" | jq -r '.ok.content[]."1".balance1 | gsub("_"; "") | tonumber' | awk '{sum += $1} END {print sum}')

echo "--------- All User Positions ---------"
result=$(dfx canister --network=ic call $poolId getUserPositions "(0, 1000)" --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)

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

    # If ids length exceeds 50, store in array and reset
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
    result=$(dfx canister --network=ic call $poolId batchRefreshIncome "(vec {${ids}})" --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)
    
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

echo "--------- Final Results ---------"

echo "Token0 balance: $token0Balance"
echo "Token1 balance: $token1Balance"
echo "Unused Token0 Balance: $unusedToken0Balance"
echo "Unused Token1 Balance: $unusedToken1Balance"
echo "Computed position amount0: $computedPositionTotalAmount0"
echo "Computed position amount1: $computedPositionTotalAmount1"
echo "Position total fees0: $positionTotalFees0"
echo "Position total fees1: $positionTotalFees1"
echo "Computed position total fees0: $computedPositionTotalFees0"
echo "Computed position total fees1: $computedPositionTotalFees1"
echo "TokenAmountState amount0: $positionToken0Amount"
echo "TokenAmountState amount1: $positionToken1Amount"
echo "TokenAmountState fee0 repurchase: $swapFee0Repurchase"
echo "TokenAmountState fee1 repurchase: $swapFee1Repurchase"

# Calculate the difference between the total position amount and the token balance
token0Difference_1=$(echo "$token0Balance - $unusedToken0Balance - $swapFee0Repurchase - $computedPositionTotalAmount0 - $computedPositionTotalFees0" | bc -l)
token1Difference_1=$(echo "$token1Balance - $unusedToken1Balance - $swapFee1Repurchase - $computedPositionTotalAmount1 - $computedPositionTotalFees1" | bc -l)

echo "Token0 difference 1: $token0Difference_1"
echo "Token1 difference 1: $token1Difference_1"

token0Difference_2=$(echo "$token0Balance - $unusedToken0Balance  - $positionToken0Amount" | bc -l)
token1Difference_2=$(echo "$token1Balance - $unusedToken1Balance  - $positionToken1Amount" | bc -l)

echo "Token0 difference 2: $token0Difference_2"
echo "Token1 difference 2: $token1Difference_2"

dfx stop

mv dfx.json.bak dfx.json
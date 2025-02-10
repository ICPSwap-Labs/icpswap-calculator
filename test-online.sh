#!/bin/bash

calculatorId="phr2m-oyaaa-aaaag-qjuoq-cai"
poolId="mhecj-xyaaa-aaaag-qjyjq-cai"
decimal0=8
decimal1=6
decimal0Float=8.0
decimal1Float=6.0
lowerPrice=50000.0
upperPrice=200000.0
fee=3000
amount0Desired=100000000
amount1Desired=1000000000000000

sh build.sh

result=$(dfx canister --network=ic call $poolId metadata --candid .dfx/local/canisters/SwapPool/SwapPool.did | idl2json)
echo "Metadata result: $result"

# echo "Full JSON structure:"
# echo $result | jq '.'

sqrtPriceX96=$(echo $result | jq -r '.ok.sqrtPriceX96')
currentTick=$(echo $result | jq -r '.ok.tick')

echo "sqrtPriceX96: $sqrtPriceX96"
echo "currentTick: $currentTick"

result2=$(dfx canister --network=ic call $calculatorId getPrice "($sqrtPriceX96, $decimal0, $decimal1)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "Price result: $result2"

result3=$(dfx canister --network=ic call $calculatorId priceToTick "($lowerPrice: float64, $decimal0Float: float64, $decimal1Float: float64, $fee: nat)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "PriceToTick result: $result3"

result4=$(dfx canister --network=ic call $calculatorId priceToTick "($upperPrice: float64, $decimal0Float: float64, $decimal1Float: float64, $fee: nat)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "PriceToTick result: $result4"

lowerTick=$(echo $result3 | jq -r '.')
upperTick=$(echo $result4 | jq -r '.')

echo "lowerTick: $lowerTick"
echo "upperTick: $upperTick"

result5=$(dfx canister --network=ic call $calculatorId getPositionTokenAmount "($sqrtPriceX96, $currentTick, $lowerTick, $upperTick, $amount0Desired, $amount1Desired)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "GetPositionTokenAmount result: $result5"
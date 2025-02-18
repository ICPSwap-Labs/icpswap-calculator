#!/bin/bash

calculatorId="phr2m-oyaaa-aaaag-qjuoq-cai"
poolId="ttwjl-6qaaa-aaaar-qaoea-cai"
decimal0=6
decimal1=18
decimal0Float=6.0
decimal1Float=18.0
lowerPrice=0.05
upperPrice=3.0
fee=3000
amount0Desired=1000000
amount1Desired=2000000000000000000

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

result6=$(dfx canister --network=ic call $calculatorId getSqrtRatioAtTick "($lowerTick)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
lowerPrice=$(echo $result6 | jq -r '.ok')
echo "GetSqrtRatioAtLowerTick result: $lowerPrice"

result7=$(dfx canister --network=ic call $calculatorId getPrice "($lowerPrice, $decimal0, $decimal1)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "Lower Price result: $result7"

result8=$(dfx canister --network=ic call $calculatorId getSqrtRatioAtTick "($upperTick)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
upperPrice=$(echo $result8 | jq -r '.ok')
echo "GetSqrtRatioAtUpperTick result: $upperPrice"

result9=$(dfx canister --network=ic call $calculatorId getPrice "($upperPrice, $decimal0, $decimal1)" --candid .dfx/local/canisters/SwapCalculator/SwapCalculator.did | idl2json)
echo "Upper Price result: $result9"
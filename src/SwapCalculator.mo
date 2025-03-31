import Error "mo:base/Error";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Int "mo:base/Int";
import Hash "mo:base/Hash";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Cycles "mo:base/ExperimentalCycles";
import IntUtils "mo:commons/math/SafeInt/IntUtils";
import SafeUint "mo:commons/math/SafeUint";
import SafeInt "mo:commons/math/SafeInt";
import SqrtPriceMath "mo:icpswap-v3-service/libraries/SqrtPriceMath";
import TickMath "mo:icpswap-v3-service/libraries/TickMath";
import LiquidityAmounts "mo:icpswap-v3-service/libraries/LiquidityAmounts";
import Types "mo:icpswap-v3-service/Types";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";

shared (initMsg) actor class SwapCalculator() {

    private stable var Q192 = (2 ** 96) ** 2;
    private stable var Q96 : Float = 0x1000000000000000000000000;
    private stable var FeeTickSpacing : [(Nat, Int)] = [(500, 10), (3000, 60), (10000, 200)];
    private stable var MaxTick : [(Nat, Int)] = [(500, 887270), (3000, 887220), (10000, 887200)];
    private stable var MinTick : [(Nat, Int)] = [(500, -887270), (3000, -887220), (10000, -887200)];

    public query func getPrice(sqrtPriceX96 : Nat, decimals0 : Nat, decimals1 : Nat) : async Float {
        let DECIMALS = 10000000;

        let part1 = sqrtPriceX96 ** 2 * 10 ** decimals0 * DECIMALS;
        let part2 = Q192 * 10 ** decimals1;
        let priceWithDecimals = Float.div(Float.fromInt(part1), Float.fromInt(part2));
        return Float.div(priceWithDecimals, Float.fromInt(DECIMALS));
    };

    public query func getSqrtPriceX96(price : Float, decimals0 : Float, decimals1 : Float) : async Int {
        // sqrtPriceX96 = sqrt(price) * 2 ** 96
        Float.toInt(Float.sqrt(price * (10 ** decimals1) / (10 ** decimals0)) * Q96);
    };

    public query func getSqrtPriceX96_2(price : Float, decimals0 : Float, decimals1 : Float) : async Int {
        _getSqrtPriceX96_2(price, decimals0, decimals1);
    };

    public query func priceToTick(price : Float, decimals0 : Float, decimals1 : Float, fee : Nat) : async Int {
        var feeTickSpacingMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(FeeTickSpacing.vals(), 3, Nat.equal, Hash.hash);
        var maxTickMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(MaxTick.vals(), 3, Nat.equal, Hash.hash);
        var minTickMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(MinTick.vals(), 3, Nat.equal, Hash.hash);

        var tickSpacing = switch (feeTickSpacingMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };
        var maxTick = switch (maxTickMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };
        var minTick = switch (minTickMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };

        var sqrtPriceX96 = IntUtils.toNat(Float.toInt(Float.sqrt(price * (10 ** decimals1) / (10 ** decimals0)) * Q96), 256);
        switch (TickMath.getTickAtSqrtRatio(SafeUint.Uint160(sqrtPriceX96))) {
            case (#ok(r)) {
                var addFlag = if (Int.rem(r, tickSpacing) >= (tickSpacing / 2)) {
                    true;
                } else { false };
                var tick = r / tickSpacing * tickSpacing;
                if (addFlag) {
                    if (tick >= 0) {
                        if (tick + tickSpacing > maxTick) {
                            maxTick;
                        } else {
                            tick + tickSpacing;
                        };
                    } else {
                        if (tick - tickSpacing < minTick) {
                            minTick;
                        } else {
                            tick - tickSpacing;
                        };
                    };
                } else { tick };
            };
            case (#err(code)) {
                throw Error.reject("TickMath.getTickAtSqrtRatio failed: " # code);
            };
        };
    };

    public query func priceToTick_2(price : Float, decimals0 : Float, decimals1 : Float, fee : Nat) : async Int {
        var feeTickSpacingMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(FeeTickSpacing.vals(), 3, Nat.equal, Hash.hash);
        var maxTickMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(MaxTick.vals(), 3, Nat.equal, Hash.hash);
        var minTickMap : HashMap.HashMap<Nat, Int> = HashMap.fromIter<Nat, Int>(MinTick.vals(), 3, Nat.equal, Hash.hash);

        var tickSpacing = switch (feeTickSpacingMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };
        var maxTick = switch (maxTickMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };
        var minTick = switch (minTickMap.get(fee)) {
            case (?r) { r };
            case (_) { 0 };
        };

        var sqrtPriceX96 = IntUtils.toNat(_getSqrtPriceX96_2(price, decimals0, decimals1), 256);
        switch (TickMath.getTickAtSqrtRatio(SafeUint.Uint160(sqrtPriceX96))) {
            case (#ok(r)) {
                var addFlag = if (Int.rem(r, tickSpacing) >= (tickSpacing / 2)) {
                    true;
                } else { false };
                var tick = r / tickSpacing * tickSpacing;
                if (addFlag) {
                    if (tick >= 0) {
                        if (tick + tickSpacing > maxTick) {
                            maxTick;
                        } else {
                            tick + tickSpacing;
                        };
                    } else {
                        if (tick - tickSpacing < minTick) {
                            minTick;
                        } else {
                            tick - tickSpacing;
                        };
                    };
                } else { tick };
            };
            case (#err(code)) {
                throw Error.reject("TickMath.getTickAtSqrtRatio failed: " # code);
            };
        };
    };

    public query func getPositionTokenAmount(
        sqrtPriceX96 : Nat,
        tickCurrent : Int,
        tickLower : Int,
        tickUpper : Int,
        amount0Desired : Nat,
        amount1Desired : Nat,
    ) : async { amount0 : Int; amount1 : Int } {
        var sqrtRatioAX96 = switch (TickMath.getSqrtRatioAtTick(SafeInt.Int24(tickLower))) {
            case (#ok(r)) { SafeUint.Uint160(r) };
            case (#err(code)) {
                throw Error.reject("Compute sqrtRatioAX96 failed: " # debug_show (code));
            };
        };
        var sqrtRatioBX96 = switch (TickMath.getSqrtRatioAtTick(SafeInt.Int24(tickUpper))) {
            case (#ok(r)) { SafeUint.Uint160(r) };
            case (#err(code)) {
                throw Error.reject("Compute sqrtRatioBX96 failed: " # debug_show (code));
            };
        };
        var liquidityDelta = LiquidityAmounts.getLiquidityForAmounts(
            SafeUint.Uint160(sqrtPriceX96),
            sqrtRatioAX96,
            sqrtRatioBX96,
            SafeUint.Uint256(amount0Desired),
            SafeUint.Uint256(amount1Desired),
        );
        var amount0 : Int = 0;
        var amount1 : Int = 0;
        if (liquidityDelta != 0) {
            if (tickCurrent < tickLower) {
                amount0 := switch (
                    SqrtPriceMath.getAmount0Delta(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        SafeInt.Int128(liquidityDelta),
                    )
                ) {
                    case (#ok(result)) { result };
                    case (#err(code)) {
                        throw Error.reject("SqrtPriceMath.getAmount0Delta failed: " # debug_show (code));
                    };
                };
            } else if (tickCurrent < tickUpper) {
                amount0 := switch (
                    SqrtPriceMath.getAmount0Delta(
                        SafeUint.Uint160(sqrtPriceX96),
                        sqrtRatioBX96,
                        SafeInt.Int128(liquidityDelta),
                    )
                ) {
                    case (#ok(result)) { result };
                    case (#err(code)) {
                        throw Error.reject("SqrtPriceMath.getAmount0Delta failed: " # debug_show (code));
                    };
                };
                amount1 := switch (
                    SqrtPriceMath.getAmount1Delta(
                        sqrtRatioAX96,
                        SafeUint.Uint160(sqrtPriceX96),
                        SafeInt.Int128(liquidityDelta),
                    )
                ) {
                    case (#ok(result)) { result };
                    case (#err(code)) {
                        throw Error.reject("SqrtPriceMath.getAmount1Delta failed: " # debug_show (code));
                    };
                };
            } else {
                amount1 := switch (
                    SqrtPriceMath.getAmount1Delta(
                        sqrtRatioAX96,
                        sqrtRatioBX96,
                        SafeInt.Int128(liquidityDelta),
                    )
                ) {
                    case (#ok(result)) { result };
                    case (#err(code)) {
                        throw Error.reject("SqrtPriceMath.getAmount1Delta failed: " # debug_show (code));
                    };
                };
            };
        };
        return { amount0 = amount0; amount1 = amount1 };
    };

    public query func getTokenAmountByLiquidity(
        sqrtPriceX96 : Nat,
        tickLower : Int,
        tickUpper : Int,
        liquidity : Nat,
    ) : async { amount0 : Int; amount1 : Int } {
        var sqrtRatioAX96 = switch (TickMath.getSqrtRatioAtTick(SafeInt.Int24(tickLower))) {
            case (#ok(r)) { r };
            case (#err(code)) {
                throw Error.reject("TickMath getSqrtRatio A AtTick " # debug_show (code));
            };
        };
        var sqrtRatioBX96 = switch (TickMath.getSqrtRatioAtTick(SafeInt.Int24(tickUpper))) {
            case (#ok(r)) { r };
            case (#err(code)) {
                throw Error.reject("TickMath getSqrtRatio B AtTick " # debug_show (code));
            };
        };
        var result = LiquidityAmounts.getAmountsForLiquidity(
            SafeUint.Uint160(sqrtPriceX96),
            SafeUint.Uint160(sqrtRatioAX96),
            SafeUint.Uint160(sqrtRatioBX96),
            SafeUint.Uint128(liquidity),
        );
        return { amount0 = result.amount0; amount1 = result.amount1 };
    };

    public query func sortToken(token0 : Text, token1 : Text) : async (Text, Text) {
        if (token0 > token1) { (token1, token0) } else { (token0, token1) };
    };

    public query func getSqrtRatioAtTick(tick : Int) : async Result.Result<Nat, Text> {
        switch (TickMath.getSqrtRatioAtTick(SafeInt.Int24(tick))) {
            case (#ok(r)) { #ok(r) };
            case (#err(code)) { #err("TickMath.getSqrtRatioAtTick failed: " # debug_show (code)) };
        };
    };

    public query func principalToBlob(p: Principal): async Blob {
        var arr: [Nat8] = Blob.toArray(Principal.toBlob(p));
        var defaultArr: [var Nat8] = Array.init<Nat8>(32, 0);
        defaultArr[0] := Nat8.fromNat(arr.size());
        var ind: Nat = 0;
        while (ind < arr.size() and ind < 32) {
            defaultArr[ind + 1] := arr[ind];
            ind := ind + 1;
        };
        return Blob.fromArray(Array.freeze(defaultArr));
    };

    private func _getSqrtPriceX96_2(price : Float, decimals0 : Float, decimals1 : Float) : Int {
        let priceText = Float.toText(price);
        let priceArray : [Text] = Iter.toArray(Text.split(priceText, #char '.'));
        let whole = priceArray[0];
        let fraction = priceArray[1];

        let decimals = fraction.size();
        let withoutDecimals = (if (Text.size(whole) > 0) { whole } else { "" }) # (if (Text.size(fraction) > 0) { fraction } else { "" });

        let denominatorPart1 = 10 ** decimals;
        let denominatorPart2 = 10 ** (Float.toInt(decimals0));
        let preDenominator = denominatorPart1 * denominatorPart2;
        let preNumerator = switch (Nat.fromText(withoutDecimals)) {
            case (?r) { r * IntUtils.toNat(10 ** Float.toInt(decimals1), 256) };
            case (_) { 0 };
        };

        let numerator = IntUtils.bitshiftLeft(preNumerator, 192, SafeInt.INT_512_MAX, SafeInt.INT_512_MIN);
        let denominator = IntUtils.toNat(preDenominator, 256);
        let ratioX192 = numerator / denominator;

        Float.toInt(Float.sqrt(Float.fromInt(ratioX192)));
    };

    public shared func getCycleInfo() : async Result.Result<Types.CycleInfo, Types.Error> {
        return #ok({
            balance = Cycles.balance();
            available = Cycles.available();
        });
    };
};

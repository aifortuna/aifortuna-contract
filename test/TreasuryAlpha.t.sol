// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../src/Treasury.sol";
import "../src/interfaces/ITreasuryHedge.sol";
import "../src/mock/MockERC20.sol";

contract TreasuryHarness is Treasury {
    constructor() {
        // Bypass initializer path for tests; set params directly for computeAlpha
        gamma = 1e18; // identity gamma
        basePrice = 5e16; // 0.05
        upPrice = 2e17; // 0.20
        downPrice = 25e15; // 0.025
    }

    function setGammaUnsafe(uint256 g) external {
        gamma = g;
    }
}

contract TreasuryAlphaTest is Test {
    TreasuryHarness treasury;

    uint256 constant ONE = 1e18;

    function setUp() public {
        treasury = new TreasuryHarness();
    }

    function _hp(uint256 price, bool isBuy) internal view returns (ITreasuryHedge.HedgeParams memory p) {
        p = ITreasuryHedge.HedgeParams({
            price: price,
            basePrice: treasury.basePrice(),
            upPrice: treasury.upPrice(),
            downPrice: treasury.downPrice(),
            isBuy: isBuy,
            isUpZone: price >= treasury.basePrice()
        });
    }

    function test_UpZone_Endpoints() public view {
        // price = base -> t=0 -> s=0 -> alpha=50%
        uint256 a0 = treasury.computeAlpha(_hp(treasury.basePrice(), true));
        assertEq(a0, 5000);

        // price = up -> t=1 -> s=1 -> alpha=100%
        uint256 a1 = treasury.computeAlpha(_hp(treasury.upPrice(), true));
        assertEq(a1, 10000);
    }

    function test_DownZone_Endpoints_Buy() public view {
        // price = base -> 50%
        uint256 a0 = treasury.computeAlpha(_hp(treasury.basePrice(), true));
        assertEq(a0, 5000);
        // price = down -> 10% (5000 - 4000)
        uint256 a1 = treasury.computeAlpha(_hp(treasury.downPrice(), true));
        assertEq(a1, 1000);
    }

    function test_DownZone_Endpoints_Sell() public view {
        // price = base -> 50%
        uint256 a0 = treasury.computeAlpha(_hp(treasury.basePrice(), false));
        assertEq(a0, 5000);
        // price = down -> 90% (5000 + 4000)
        uint256 a1 = treasury.computeAlpha(_hp(treasury.downPrice(), false));
        assertEq(a1, 9000);
    }

    function testFuzz_Monotonic_UpZone(uint256 pRaw) public view {
        uint256 base = treasury.basePrice();
        uint256 up = treasury.upPrice();
        vm.assume(up > base);
        uint256 price1 = base + (pRaw % (up - base));
        uint256 price2 = price1;
        if (price2 < up) price2 += 1; // ensure non-decreasing price
        uint256 a1 = treasury.computeAlpha(_hp(price1, true));
        uint256 a2 = treasury.computeAlpha(_hp(price2, true));
        assertLe(a1, a2);
    }

    function testFuzz_Monotonic_DownZone_Buy(uint256 pRaw) public view {
        uint256 base = treasury.basePrice();
        uint256 down = treasury.downPrice();
        vm.assume(base > down);
        uint256 span = base - down;
        uint256 price1 = down + 1 + (pRaw % (span - 1));
        // Map to down-zone decreasing t (price closer to down => larger t => smaller alpha for buy)
        uint256 a1 = treasury.computeAlpha(_hp(price1, true));
        uint256 price2 = price1;
        if (price2 > down) price2 -= 1; // closer to down
        uint256 a2 = treasury.computeAlpha(_hp(price2, true));
        assertGe(a1, a2); // as price goes downwards, alpha should not increase for buy
    }

    function testFuzz_Monotonic_DownZone_Sell(uint256 pRaw) public view {
        uint256 base = treasury.basePrice();
        uint256 down = treasury.downPrice();
        vm.assume(base > down);
        uint256 span = base - down;
        uint256 price1 = down + 1 + (pRaw % (span - 1));
        uint256 a1 = treasury.computeAlpha(_hp(price1, false));
        uint256 price2 = price1;
        if (price2 > down) price2 -= 1; // closer to down -> larger s -> larger alpha for sell
        uint256 a2 = treasury.computeAlpha(_hp(price2, false));
        assertLe(a1, a2);
    }

    function _boundGamma(uint256 gRaw) internal pure returns (uint256) {
        // Library behavior is well-defined in [0.5, 2];
        // for >2 it clamps to s^2, so fuzz within [0.5, 2] to avoid rounding edge-cases.
        if (gRaw < 5e17) return 5e17;
        if (gRaw > 2e18) return 2e18 - 1;
        return gRaw;
    }

    function testFuzz_Range_UpZone_Buy(uint256 pRaw, uint256 gRaw) public {
        uint256 base = treasury.basePrice();
        uint256 up = treasury.upPrice();
        vm.assume(up > base);
        uint256 price = base + (pRaw % (up - base));
        uint256 gamma = _boundGamma(gRaw);
        treasury.setGammaUnsafe(gamma);
        uint256 a = treasury.computeAlpha(_hp(price, true));
        assertGe(a, 5000);
        assertLe(a, 10000);
    }

    function testFuzz_Range_UpZone_Sell(uint256 pRaw, uint256 gRaw) public {
        uint256 base = treasury.basePrice();
        uint256 up = treasury.upPrice();
        vm.assume(up > base);
        uint256 price = base + (pRaw % (up - base));
        uint256 gamma = _boundGamma(gRaw);
        treasury.setGammaUnsafe(gamma);
        uint256 a = treasury.computeAlpha(_hp(price, false));
        assertGe(a, 5000);
        assertLe(a, 10000);
    }

    function testFuzz_Range_DownZone_Buy(uint256 pRaw) public {
        uint256 base = treasury.basePrice();
        uint256 down = treasury.downPrice();
        vm.assume(base > down);
        uint256 price = down + 1 + (pRaw % (base - down - 1));
        treasury.setGammaUnsafe(1e18); // fix gamma to identity for range check
        uint256 a = treasury.computeAlpha(_hp(price, true));
        assertGe(a, 1000);
        assertLe(a, 5000);
    }

    function testFuzz_Range_DownZone_Sell(uint256 pRaw) public {
        uint256 base = treasury.basePrice();
        uint256 down = treasury.downPrice();
        vm.assume(base > down);
        uint256 price = down + 1 + (pRaw % (base - down - 1));
        treasury.setGammaUnsafe(1e18); // fix gamma to identity for range check
        uint256 a = treasury.computeAlpha(_hp(price, false));
        assertGe(a, 5000);
        assertLe(a, 9000);
    }

    function testFuzz_Clamp_Outside_Ranges(uint256 pRaw, bool chooseUpper, bool isBuy, uint256 gRaw) public {
        uint256 base = treasury.basePrice();
        uint256 up = treasury.upPrice();
        uint256 down = treasury.downPrice();
        uint256 price;
        if (chooseUpper) {
            price = up + 1 + (pRaw % (10 * 1e18));
        } else {
            // avoid underflow, clamp to >=0
            price = down > 0 ? (down - 1) : 0;
        }
        uint256 gamma = _boundGamma(gRaw);
        treasury.setGammaUnsafe(gamma);
        ITreasuryHedge.HedgeParams memory p = _hp(price, isBuy);
        uint256 a = treasury.computeAlpha(p);
        if (p.price >= base) {
            assertEq(a, 10000);
        } else {
            if (isBuy) assertEq(a, 1000);
            else assertEq(a, 9000);
        }
    }

    function testFuzz_GammaMonotonic_UpZone(uint256 g1Raw, uint256 g2Raw, bool isBuy) public {
        // price at interior
        uint256 price = (treasury.basePrice() + treasury.upPrice()) / 2;
        uint256 g1 = _boundGamma(g1Raw);
        uint256 g2 = _boundGamma(g2Raw);
        if (g1 == g2) g2 = g1 + 1;
        // Ensure gLow < gHigh
        uint256 gLow = g1 < g2 ? g1 : g2;
        uint256 gHigh = g1 < g2 ? g2 : g1;
        treasury.setGammaUnsafe(gLow);
        uint256 aLow = treasury.computeAlpha(_hp(price, isBuy));
        treasury.setGammaUnsafe(gHigh);
        uint256 aHigh = treasury.computeAlpha(_hp(price, isBuy));
        // s decreases with gamma -> up-zone alpha decreases with gamma
        assertGe(aLow, aHigh);
    }

    function testFuzz_GammaMonotonic_Down_Buy(uint256 g1Raw, uint256 g2Raw) public {
        uint256 price = (treasury.basePrice() + treasury.downPrice()) / 2;
        uint256 g1 = _boundGamma(g1Raw);
        uint256 g2 = _boundGamma(g2Raw);
        if (g1 == g2) g2 = g1 + 1;
        uint256 gLow = g1 < g2 ? g1 : g2;
        uint256 gHigh = g1 < g2 ? g2 : g1;
        treasury.setGammaUnsafe(gLow);
        uint256 aLow = treasury.computeAlpha(_hp(price, true));
        treasury.setGammaUnsafe(gHigh);
        uint256 aHigh = treasury.computeAlpha(_hp(price, true));
        // s decreases with gamma -> down-zone buy alpha increases with gamma
        assertLe(aLow, aHigh);
    }

    function testFuzz_GammaMonotonic_Down_Sell(uint256 g1Raw, uint256 g2Raw) public {
        uint256 price = (treasury.basePrice() + treasury.downPrice()) / 2;
        uint256 g1 = _boundGamma(g1Raw);
        uint256 g2 = _boundGamma(g2Raw);
        if (g1 == g2) g2 = g1 + 1;
        uint256 gLow = g1 < g2 ? g1 : g2;
        uint256 gHigh = g1 < g2 ? g2 : g1;
        treasury.setGammaUnsafe(gLow);
        uint256 aLow = treasury.computeAlpha(_hp(price, false));
        treasury.setGammaUnsafe(gHigh);
        uint256 aHigh = treasury.computeAlpha(_hp(price, false));
        // s decreases with gamma -> down-zone sell alpha decreases with gamma
        assertGe(aLow, aHigh);
    }
}

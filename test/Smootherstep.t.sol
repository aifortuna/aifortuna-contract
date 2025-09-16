// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../src/math/Smootherstep.sol";

contract SmootherstepHarness {
    using SmootherstepMath for uint256;

    function s(uint256 t) external pure returns (uint256) {
        return SmootherstepMath.smootherstep(t);
    }

    function sg(uint256 t, uint256 gamma) external pure returns (uint256) {
        return SmootherstepMath.smootherGamma(t, gamma);
    }
}

contract SmootherstepTest is Test {
    using SmootherstepMath for uint256;

    uint256 constant ONE = 1e18;

    SmootherstepHarness internal h;

    function setUp() public {
        h = new SmootherstepHarness();
    }

    function sqrtWadLocal(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 r = Math.sqrt(x);
        return r * 1e9;
    }

    function test_Smootherstep_Endpoints() public pure {
        assertEq(SmootherstepMath.smootherstep(0), 0, "s(0)=0");
        assertEq(SmootherstepMath.smootherstep(ONE), ONE, "s(1)=1");
    }

    function testFuzz_Smootherstep_Bounds(uint256 tRaw) public pure {
        uint256 t = tRaw % (ONE + 1); // [0,1e18]
        uint256 s = SmootherstepMath.smootherstep(t);
        assertLe(s, ONE, "s<=1");
        // underflow-proof: s is uint, implicitly >= 0
    }

    function test_Smootherstep_Monotonic_Sampled() public pure {
        uint256 prev = 0;
        uint256 steps = 256;
        for (uint256 i = 0; i <= steps; i++) {
            uint256 t = (i * ONE) / steps;
            uint256 s = SmootherstepMath.smootherstep(t);
            assertGe(s, prev, "monotonic non-decreasing");
            prev = s;
        }
    }

    function testFuzz_Gamma_Identity(uint256 tRaw) public view {
        uint256 t = bound(tRaw, 0, ONE);
        uint256 base = h.s(t);
        uint256 out = h.sg(t, ONE);
        assertEq(out, base, "gamma=1 keeps base");
    }

    function testFuzz_Gamma_GT1_Le_Base(uint256 tRaw, uint256 gRaw) public view {
        uint256 t = bound(tRaw, 1, ONE - 1); // avoid endpoints
        uint256 gamma = bound(gRaw, ONE + 1, 2 * ONE); // (1,2]
        uint256 base = h.s(t);
        uint256 out = h.sg(t, gamma);
        assertLe(out, base, ">1 bends down (<= base)");
    }

    function testFuzz_Gamma_LT1_Ge_Base(uint256 tRaw, uint256 gRaw) public view {
        uint256 t = bound(tRaw, 1, ONE - 1); // avoid endpoints
        uint256 gamma = bound(gRaw, 5e17, ONE - 1); // [0.5,1)
        uint256 base = h.s(t);
        uint256 out = h.sg(t, gamma);
        assertGe(out, base, "<1 bends up (>= base)");
    }

    function test_Gamma_Clamp_To_Square() public view {
        uint256 t = ONE / 3; // arbitrary interior point
        uint256 base = h.s(t);
        uint256 out = h.sg(t, 3 * ONE); // >2 => clamp to square
        uint256 base2 = (base * base) / ONE;
        assertEq(out, base2, ">2 clamps to s^2");
    }

    function test_Gamma_Clamp_To_Sqrt() public view {
        uint256 t = (7 * ONE) / 10; // arbitrary interior point
        uint256 base = h.s(t);
        uint256 out = h.sg(t, 0); // <0.5 => clamp to sqrt
        uint256 sSqrt = sqrtWadLocal(base);
        assertEq(out, sSqrt, "<0.5 clamps to sqrt(s)");
    }
}

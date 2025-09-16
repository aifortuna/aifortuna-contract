// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/Math.sol";

/// @title SmootherstepMath
/// @notice Library for computing smootherstep with optional curvature control (gamma) using 1e18 fixed-point
library SmootherstepMath {
    uint256 internal constant ONE = 1e18;
    uint256 internal constant HALF = 5e17;

    /// @notice compute base smootherstep s0(t) = 6t^5 - 15t^4 + 10t^3 for t in [0,1]
    /// @param t 1e18 scaled
    function smootherstep(uint256 t) internal pure returns (uint256) {
        if (t == 0) return 0; // gas shortcut
        if (t >= ONE) return ONE;
        // Use 256-bit intermediate with unchecked ops
        unchecked {
            uint256 t2 = (t * t) / ONE; // t^2
            uint256 t3 = (t2 * t) / ONE; // t^3
            uint256 t4 = (t3 * t) / ONE; // t^4
            uint256 t5 = (t4 * t) / ONE; // t^5
            // 6 t^5 - 15 t^4 + 10 t^3
            uint256 term1 = 6 * t5; // 6 t^5
            uint256 term2 = 15 * t4; // 15 t^4
            uint256 term3 = 10 * t3; // 10 t^3
            // Saturate to 0 to avoid rare underflow due to integer rounding
            uint256 sum = term1 + term3;
            return sum >= term2 ? (sum - term2) : 0;
        }
    }

    /// @notice sqrt in 1e18 fixed-point: returns floor(sqrt(x/1e18) * 1e18)
    function sqrtWad(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // Integer sqrt of the wad, then scale by 1e9 to preserve wad scale
        uint256 r = Math.sqrt(x);
        return r * 1e9;
    }

    /// @notice Apply curvature gamma to smootherstep result.
    /// @dev Gamma is 1e18 = identity. For gamma in (1,2], blend towards square (more concave down).
    ///      For gamma in [0.5,1), blend towards sqrt (more concave up). Values <0.5 clamp to 0.5; >2 clamp to 2.
    /// @param t input in 1e18 scale
    /// @param gamma curvature in 1e18 (valid range [0.5, 2.0] scaled as [5e17, 2e18])
    function smootherGamma(uint256 t, uint256 gamma) internal pure returns (uint256) {
        uint256 s = smootherstep(t);
        if (gamma == ONE || s == 0 || s == ONE) return s;
        unchecked {
            if (gamma > ONE) {
                // Map gamma in [1,2] -> weight w in [0,1]
                uint256 w = gamma - ONE;
                if (w > ONE) w = ONE; // clamp >2
                uint256 s2 = (s * s) / ONE; // s^2 (<= s)
                // Blend towards s^2: s - (s - s2) * w
                uint256 dec = ((s - s2) * w) / ONE;
                uint256 out = s - dec;
                return out; // always <= s and >= 0
            } else {
                // gamma in [0.5,1): map to weight w in [0,1]
                // w = (1 - gamma) / (1 - 0.5) = 2 * (1 - gamma)
                uint256 w2 = (ONE - gamma) * 2;
                if (w2 > ONE) w2 = ONE; // clamp <0.5
                uint256 sSqrt = sqrtWad(s); // >= s
                // Guard rounding: if sSqrt < s due to flooring, treat delta as 0
                if (sSqrt <= s) return s;
                uint256 inc = ((sSqrt - s) * w2) / ONE;
                uint256 out2 = s + inc;
                // Clamp to ONE to preserve range
                return out2 > ONE ? ONE : out2;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ITreasuryHedge {
    struct HedgeParams {
        uint256 price; // current price scaled 1e18 (USDT per FUSD)
        uint256 basePrice; // anchor price (0.05 * 1e18)
        uint256 upPrice; // upper extreme
        uint256 downPrice; // lower extreme
        bool isBuy; // user action: buying FUSD (true) or selling FUSD
        bool isUpZone; // price in upper band (>= base)
    }

    event HedgeExecuted(
        bool userBuy, uint256 userAmount, uint256 hedgeAmount, uint256 alpha, uint256 price, bool upZone
    );
    event GammaUpdated(uint256 oldGamma, uint256 newGamma);
    event FeeToLPUpdated(uint256 oldPct, uint256 newPct);

    function computeAlpha(HedgeParams calldata p) external view returns (uint256 alphaBps);

    function gamma() external view returns (uint256);

    function execute(uint256 amount, bool isBuy) external;

    function executeHedge(uint256 userAmount, HedgeParams calldata p)
        external
        returns (uint256 hedgeAmount, uint256 alphaBps);

    // Price boundary getters
    function basePrice() external view returns (uint256);

    function upPrice() external view returns (uint256);

    function downPrice() external view returns (uint256);
}

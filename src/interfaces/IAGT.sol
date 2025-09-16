// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAGT {
    function balanceOf(address) external view returns (uint256);

    function addWhitelist(address account) external;

    function burn(uint256 amount) external;
}

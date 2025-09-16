// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InteractionBase.s.sol";

contract AGTInteraction is InteractionBase {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // Example: Add Fortuna to whitelist if not already
        if (!agt.whitelist(fortunaAddress)) {
            agt.addToWhitelist(fortunaAddress, true);
            console.log("Added Fortuna to AGT whitelist");
        }

        vm.stopBroadcast();
    }

    // === Game Contract Management ===

    function setGameContract(address gameContract) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.setGameContract(gameContract);
        console.log("Set game contract to:", gameContract);
        vm.stopBroadcast();
    }

    function setApprove(address spender, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.approve(spender, amount);
        console.log("Approved %s to spend %d AGT", spender, amount);
        vm.stopBroadcast();
    }

    function setApproveMax(address spender) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.approve(spender, type(uint256).max);
        console.log("Approved", spender, "to spend unlimited AGT");
        vm.stopBroadcast();
    }

    // === Whitelist Management ===

    function setWhiteList(address account, bool whitelisted) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.addToWhitelist(account, whitelisted);
        console.log("Set whitelist for", account, "to", whitelisted);
        vm.stopBroadcast();
    }

    function addFortunaToWhitelist() public {
        vm.startBroadcast(deployerPrivateKey);
        agt.addToWhitelist(fortunaAddress, true);
        console.log("Added Fortuna to whitelist:", fortunaAddress);
        vm.stopBroadcast();
    }

    // === Fee Management ===

    function setFeeExempt(address account, bool exempt) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.setFeeExempt(account, exempt);
        console.log("Set fee exempt for", account, "to", exempt);
        vm.stopBroadcast();
    }

    function setFeeWallet(address newFeeWallet) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.setFeeWallet(newFeeWallet);
        console.log("Set fee wallet to:", newFeeWallet);
        vm.stopBroadcast();
    }

    function setFeeBps(uint256 feeBps) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.setFeeBps(feeBps);
        console.log("Set fee BPS to:", feeBps);
        vm.stopBroadcast();
    }

    // === Swap Pair Management ===

    function setSwapPair(address pair, bool isSwapPair) public {
        vm.startBroadcast(deployerPrivateKey);
        agt.setSwapPair(pair, isSwapPair);
        console.log("Set swap pair for", pair, "to", isSwapPair);
        vm.stopBroadcast();
    }

    function setupPermissions() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Setting up AGT permissions ===");

        // Add deployer to whitelist
        if (!agt.whitelist(deployerAddress)) {
            agt.addToWhitelist(deployerAddress, true);
            console.log("Added deployer to whitelist:", deployerAddress);
        }

        // Add Fortuna contract to whitelist
        if (!agt.whitelist(fortunaAddress)) {
            agt.addToWhitelist(fortunaAddress, true);
            console.log("Added Fortuna to whitelist:", fortunaAddress);
        }

        // Set Fortuna as swap pair if needed
        if (!agt.swapPairs(fortunaAddress)) {
            agt.setSwapPair(fortunaAddress, true);
            console.log("Set Fortuna as swap pair");
        }

        // Set deployer as fee exempt for testing
        if (!agt.feeExempt(deployerAddress)) {
            agt.setFeeExempt(deployerAddress, true);
            console.log("Set deployer as fee exempt");
        }

        console.log("AGT permission setup completed");
        vm.stopBroadcast();
    }

    // === View Functions ===

    function checkPermissions() public view {
        console.log("=== AGT Permission Check ===");
        console.log("Checking permissions for:", deployerAddress);

        // Check whitelist status
        console.log("Deployer whitelisted:", agt.whitelist(deployerAddress));
        console.log("Fortuna whitelisted:", agt.whitelist(fortunaAddress));

        // Check swap pair status
        console.log("Fortuna is swap pair:", agt.swapPairs(fortunaAddress));

        // Check fee exempt status
        console.log("Deployer fee exempt:", agt.feeExempt(deployerAddress));

        // Check owner
        console.log("AGT owner:", agt.owner());

        // Check game contract
        console.log("Game contract:", agt.gameContract());

        // Check fee wallet
        console.log("Fee wallet:", agt.feeWallet());

        // Check fee BPS
        console.log("Fee BPS:", agt.feeBps());
    }

    function getTokenInfo() public view {
        console.log("=== AGT Token Info ===");
        console.log("Name:", agt.name());
        console.log("Symbol:", agt.symbol());
        console.log("Decimals:", agt.decimals());
        console.log("Total Supply:", agt.totalSupply());
        console.log("Owner:", agt.owner());
    }

    function getBalance(address account) public view {
        uint256 balance = agt.balanceOf(account);
        console.log("AGT balance for", account, ":", balance);
    }

    function getAllowance(address owner, address spender) public view {
        uint256 allowance = agt.allowance(owner, spender);
        console.log("AGT allowance from %s to %s: %d", owner, spender, allowance);
    }
}

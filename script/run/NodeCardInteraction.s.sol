// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InteractionBase.s.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract NodeCardInteraction is InteractionBase {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // Example: Check oracle and vault addresses
        address currentOracle = nodeCard.oracle();
        address currentVault = nodeCard.vault();

        console.log("Current Oracle:", currentOracle);
        console.log("Current Vault:", currentVault);

        vm.stopBroadcast();
    }

    // === Configuration Functions ===

    function setOracle(address newOracle) public {
        vm.startBroadcast(deployerPrivateKey);
        nodeCard.setOracle(newOracle);
        console.log("Set oracle to:", newOracle);
        vm.stopBroadcast();
    }

    function setVault(address newVault) public {
        vm.startBroadcast(deployerPrivateKey);
        nodeCard.setVault(newVault);
        console.log("Set vault to:", newVault);
        vm.stopBroadcast();
    }

    // === Withdrawal Functions ===

    function withdrawBNB(uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 contractBalance = address(nodeCard).balance;
        console.log("Contract BNB balance:", contractBalance);

        if (amount == 0) {
            amount = contractBalance;
        }

        require(amount <= contractBalance, "Insufficient BNB balance");

        nodeCard.emergencyWithdraw(address(0), amount);
        console.log("Withdrew", amount, "BNB");

        vm.stopBroadcast();
    }

    function withdrawAllBNB() public {
        withdrawBNB(0); // 0 means withdraw all
    }

    function withdrawToken(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 contractBalance = IERC20(token).balanceOf(address(nodeCard));
        console.log("Contract token balance:", contractBalance);

        if (amount == 0) {
            amount = contractBalance;
        }

        require(amount <= contractBalance, "Insufficient token balance");

        nodeCard.emergencyWithdraw(token, amount);
        console.log("Withdrew", amount, "of token", token);

        vm.stopBroadcast();
    }

    function withdrawUSDT(uint256 amount) public {
        withdrawToken(usdtAddress, amount);
    }

    function withdrawAllUSDT() public {
        withdrawToken(usdtAddress, 0); // 0 means withdraw all
    }

    function withdrawFUSD(uint256 amount) public {
        withdrawToken(fusdAddress, amount);
    }

    function withdrawAllFUSD() public {
        withdrawToken(fusdAddress, 0); // 0 means withdraw all
    }

    function withdrawAGT(uint256 amount) public {
        withdrawToken(agtAddress, amount);
    }

    function withdrawAllAGT() public {
        withdrawToken(agtAddress, 0); // 0 means withdraw all
    }

    // === View Functions ===

    function getOracle() public view {
        address currentOracle = nodeCard.oracle();
        console.log("Oracle address:", currentOracle);
    }

    function getVault() public view {
        address currentVault = nodeCard.vault();
        console.log("Vault address:", currentVault);
    }

    function getOwner() public view {
        address currentOwner = nodeCard.owner();
        console.log("NodeCard owner:", currentOwner);
    }

    function getBNBBalance() public view {
        uint256 balance = address(nodeCard).balance;
        console.log("NodeCard BNB balance:", balance);
    }

    function getTokenBalance(address token) public view {
        uint256 balance = IERC20(token).balanceOf(address(nodeCard));
        console.log("NodeCard token balance for", token, ":", balance);
    }

    function getUSDTBalance() public view {
        getTokenBalance(usdtAddress);
    }

    function getFUSDBalance() public view {
        getTokenBalance(fusdAddress);
    }

    function getAGTBalance() public view {
        getTokenBalance(agtAddress);
    }

    function getAllBalances() public view {
        console.log("=== NodeCard Balances ===");
        getBNBBalance();
        getUSDTBalance();
        getFUSDBalance();
        getAGTBalance();
    }

    function getContractInfo() public view {
        console.log("=== NodeCard Info ===");
        getOwner();
        getOracle();
        getVault();
        getAllBalances();
    }

    // === Emergency Functions ===

    function emergencyWithdrawAll() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Emergency Withdrawal ===");

        // Withdraw all BNB
        uint256 bnbBalance = address(nodeCard).balance;
        if (bnbBalance > 0) {
            nodeCard.emergencyWithdraw(address(0), bnbBalance);
            console.log("Emergency withdrew", bnbBalance, "BNB");
        }

        // Withdraw all USDT
        uint256 usdtBalance = IERC20(usdtAddress).balanceOf(address(nodeCard));
        if (usdtBalance > 0) {
            nodeCard.emergencyWithdraw(usdtAddress, usdtBalance);
            console.log("Emergency withdrew", usdtBalance, "USDT");
        }

        // Withdraw all FUSD
        if (fusdAddress != address(0)) {
            uint256 fusdBalance = IERC20(fusdAddress).balanceOf(address(nodeCard));
            if (fusdBalance > 0) {
                nodeCard.emergencyWithdraw(fusdAddress, fusdBalance);
                console.log("Emergency withdrew", fusdBalance, "FUSD");
            }
        }

        // Withdraw all AGT
        if (agtAddress != address(0)) {
            uint256 agtBalance = IERC20(agtAddress).balanceOf(address(nodeCard));
            if (agtBalance > 0) {
                nodeCard.emergencyWithdraw(agtAddress, agtBalance);
                console.log("Emergency withdrew", agtBalance, "AGT");
            }
        }

        console.log("Emergency withdrawal completed");
        vm.stopBroadcast();
    }
}

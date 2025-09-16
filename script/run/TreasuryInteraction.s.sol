// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InteractionBase.s.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ITreasuryHedge} from "../../src/interfaces/ITreasuryHedge.sol";

contract TreasuryInteraction is InteractionBase {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // Example: Check treasury configuration
        console.log("Treasury owner:", treasury.owner());
        address firstOperator = treasury.operators(0);
        console.log("Treasury first operator:", firstOperator);

        vm.stopBroadcast();
    }

    // === Configuration Functions ===

    function setOperator(address operator) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setOperator(operator);
        console.log("Set treasury operator to:", operator);
        vm.stopBroadcast();
    }

    function setBasePrice(uint256 price) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setBasePrice(price);
        console.log("Set base price to:", price);
        vm.stopBroadcast();
    }

    function setUpPrice(uint256 price) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setUpPrice(price);
        console.log("Set up price to:", price);
        vm.stopBroadcast();
    }

    function setDownPrice(uint256 price) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setDownPrice(price);
        console.log("Set down price to:", price);
        vm.stopBroadcast();
    }

    function setPancakeRouter(address router) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setPancakeRouter(router);
        console.log("Set pancake router to:", router);
        vm.stopBroadcast();
    }

    function setLpToken(address lpToken) public {
        vm.startBroadcast(deployerPrivateKey);
        treasury.setLpToken(lpToken);
        console.log("Set LP token to:", lpToken);
        vm.stopBroadcast();
    }

    // === Treasury Operations ===

    function executeTreasury(uint256 amount, bool up) public {
        vm.startBroadcast(deployerPrivateKey);

        treasury.execute(amount, up);
        console.log("Executed treasury operation with amount:", amount, "up:", up);

        vm.stopBroadcast();
    }

    function executeHedge(uint256 amount, uint256 price, bool isBuy, bool isUpZone) public {
        vm.startBroadcast(deployerPrivateKey);

        // Create HedgeParams struct
        ITreasuryHedge.HedgeParams memory params = ITreasuryHedge.HedgeParams({
            price: price,
            basePrice: treasury.basePrice(),
            upPrice: treasury.upPrice(),
            downPrice: treasury.downPrice(),
            isBuy: isBuy,
            isUpZone: isUpZone
        });

        treasury.executeHedge(amount, params);
        console.log("Executed treasury hedge with amount:", amount);

        vm.stopBroadcast();
    }

    // === Emergency Functions ===

    function emergencyWithdraw(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        treasury.emergencyWithdraw(token, amount);
        console.log("Emergency withdrew", amount, "of", token);

        vm.stopBroadcast();
    }

    function emergencyWithdrawBNB(uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        treasury.emergencyWithdraw(address(0), amount);
        console.log("Emergency withdrew", amount, "BNB");

        vm.stopBroadcast();
    }

    function emergencyWithdrawAll() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Emergency Withdrawal from Treasury ===");

        // Withdraw all BNB
        uint256 bnbBalance = address(treasury).balance;
        if (bnbBalance > 0) {
            treasury.emergencyWithdraw(address(0), bnbBalance);
            console.log("Emergency withdrew", bnbBalance, "BNB");
        }

        // Withdraw all FUSD
        uint256 fusdBalance = IERC20(fusdAddress).balanceOf(address(treasury));
        if (fusdBalance > 0) {
            treasury.emergencyWithdraw(fusdAddress, fusdBalance);
            console.log("Emergency withdrew", fusdBalance, "FUSD");
        }

        // Withdraw all USDT
        uint256 usdtBalance = IERC20(usdtAddress).balanceOf(address(treasury));
        if (usdtBalance > 0) {
            treasury.emergencyWithdraw(usdtAddress, usdtBalance);
            console.log("Emergency withdrew", usdtBalance, "USDT");
        }

        console.log("Emergency withdrawal completed");
        vm.stopBroadcast();
    }

    // === View Functions ===

    function getTreasuryInfo() public view {
        console.log("=== Treasury Info ===");
        console.log("Owner:", treasury.owner());
        try treasury.operators(0) returns (address firstOp) {
            console.log("First Operator:", firstOp);
        } catch {
            console.log("No operators found");
        }
        console.log("Base Price:", treasury.basePrice());
        console.log("Up Price:", treasury.upPrice());
        console.log("Down Price:", treasury.downPrice());
    }

    function getTreasuryBalances() public view {
        console.log("=== Treasury Balances ===");

        uint256 bnbBalance = address(treasury).balance;
        console.log("BNB Balance:", bnbBalance);

        uint256 fusdBalance = IERC20(fusdAddress).balanceOf(address(treasury));
        console.log("FUSD Balance:", fusdBalance);

        uint256 usdtBalance = IERC20(usdtAddress).balanceOf(address(treasury));
        console.log("USDT Balance:", usdtBalance);
    }

    function getBasePrice() public view {
        uint256 price = treasury.basePrice();
        console.log("Base price:", price);
    }

    function getUpPrice() public view {
        uint256 price = treasury.upPrice();
        console.log("Up price:", price);
    }

    function getDownPrice() public view {
        uint256 price = treasury.downPrice();
        console.log("Down price:", price);
    }

    function getOperators() public view {
        console.log("=== Treasury Operators ===");

        // Try to get first few operators (there's no public length getter)
        for (uint256 i = 0; i < 10; i++) {
            try treasury.operators(i) returns (address operator) {
                console.log("Operator", i, ":", operator);
            } catch {
                if (i == 0) {
                    console.log("No operators found");
                }
                break;
            }
        }
    }

    function getOwner() public view {
        address owner = treasury.owner();
        console.log("Treasury owner:", owner);
    }

    // === Batch Operations ===

    function batchUpdatePrices(uint256 basePrice, uint256 upPrice, uint256 downPrice) public {
        vm.startBroadcast(deployerPrivateKey);

        treasury.setBasePrice(basePrice);
        treasury.setUpPrice(upPrice);
        treasury.setDownPrice(downPrice);

        console.log("Updated all treasury prices");
        console.log("Base price:", basePrice);
        console.log("Up price:", upPrice);
        console.log("Down price:", downPrice);

        vm.stopBroadcast();
    }

    function setupTreasuryForFortuna() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Setting up Treasury for Fortuna ===");

        // Set Fortuna as operator
        treasury.setOperator(fortunaAddress);
        console.log("Set Fortuna as treasury operator");

        console.log("Treasury setup for Fortuna completed");
        vm.stopBroadcast();
    }
}

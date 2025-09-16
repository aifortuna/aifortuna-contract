// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./InteractionBase.s.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract FortunaInteraction is InteractionBase {
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        // Example: Set BNB fee
        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.setBnbFee(bnbFee);
        console.log("Set BNB fee to: %d", bnbFee);

        vm.stopBroadcast();
    }

    // === Configuration Functions ===

    function setWithdrawable(address token, bool withdrawable) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setWithdrawable(token, withdrawable);
        console.log("Set withdrawable for", token, "to", withdrawable);
        vm.stopBroadcast();
    }

    function setFeeWallet(address newFeeWallet) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setFeeWallet(newFeeWallet);
        console.log("Set fee wallet to:", newFeeWallet);
        vm.stopBroadcast();
    }

    function setAgt(address newAgt) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setAgt(newAgt);
        console.log("Set AGT address to:", newAgt);
        vm.stopBroadcast();
    }

    function setClaimFeePercent(uint256 percent) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setClaimFeePercent(percent);
        console.log("Set claim fee percent to:", percent);
        vm.stopBroadcast();
    }

    function setOperateAddress(address operator) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.grantOperatorRole(operator);
        console.log("Granted operator role to:", operator);
        vm.stopBroadcast();
    }

    function setBnbFee(uint256 fee) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setBnbFee(fee);
        console.log("Set BNB fee to:", fee);
        vm.stopBroadcast();
    }

    // === Token Management ===

    function addToken(address token, uint256 minDeposit) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.addToken(token, minDeposit);
        console.log("Added token:", token, "with min deposit:", minDeposit);
        vm.stopBroadcast();
    }

    function addPancakeSwapInfos(address tokenA, address tokenB) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.addPancakeSwapInfos(tokenA, tokenB);
        console.log("Added PancakeSwap info for", tokenA, "<>", tokenB);
        vm.stopBroadcast();
    }

    function setBuyFee(address token, bool supported, uint256 feePercent) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setBuyFee(token, supported, feePercent);
        console.log("Set buy fee for %s, supported: %s, fee: %d", token, supported, feePercent);
        vm.stopBroadcast();
    }

    function setPancakeRouter(address router) public {
        vm.startBroadcast(deployerPrivateKey);
        fortuna.setPancakeRouter(router);
        console.log("Set PancakeSwap router to:", router);
        vm.stopBroadcast();
    }

    // === Gaming Functions ===

    function buyToken(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 deadline = getDeadline(300); // 5 minutes
        string memory signContext = createSignContext("buytoken");

        bytes memory signature = createOracleSignature(deployerAddress, token, amount, signContext, deadline);

        // Check and approve
        uint256 userBalance = IERC20(token).balanceOf(deployerAddress);
        console.log("User balance:", userBalance);
        require(userBalance >= amount, "Insufficient balance");

        IERC20(token).approve(fortunaAddress, amount);
        console.log("Approved Fortuna to spend tokens");

        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.buyToken{value: bnbFee}(token, amount, deadline, signContext, signature);

        console.log("Token purchase completed");
        vm.stopBroadcast();
    }

    function claimPairedTokenRewards(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 deadline = getDeadline(300);
        string memory signContext = createSignContext("claimrewards");

        bytes memory signature = createOracleSignature(deployerAddress, token, amount, signContext, deadline);

        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.claimPairedTokenRewards{value: bnbFee}(token, amount, deadline, signContext, signature);

        console.log("Claimed paired token rewards");
        vm.stopBroadcast();
    }

    function mintPairedToken(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 deadline = getDeadline(300);
        string memory signContext = createSignContext("mintpaired");

        bytes memory signature = createOracleSignature(deployerAddress, token, amount, signContext, deadline);

        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.mintPairedToken{value: bnbFee}(token, amount, deadline, signContext, signature);

        console.log("Minted paired token");
        vm.stopBroadcast();
    }

    function claimNodeCardRewards(address agtToken, uint256 agtAmount, address fusdToken, uint256 fusdAmount) public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 deadline = getDeadline(300);
        string memory signContext = createSignContext("claimnodecard");

        bytes memory signature = createOracleSignature(deployerAddress, fusdToken, fusdAmount, signContext, deadline);

        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.claimNodeCardRewards{value: bnbFee}(
            agtToken, agtAmount, fusdToken, fusdAmount, deadline, signContext, signature
        );

        console.log("Claimed NodeCard rewards");
        vm.stopBroadcast();
    }

    function swapTokensForTokens(address tokenIn, address tokenOut, uint256 amountIn, address to) public {
        vm.startBroadcast(deployerPrivateKey);

        IERC20(tokenIn).approve(fortunaAddress, amountIn);

        uint256 bnbFee = stdJson.readUint(config, ".fortuna.bnbFee");
        fortuna.swapTokensForTokens{value: bnbFee}(tokenIn, tokenOut, amountIn, to, getDeadline(300));

        console.log("Swapped tokens:", tokenIn, "->", tokenOut);
        vm.stopBroadcast();
    }

    function deposit(address token, uint256 amount) public {
        vm.startBroadcast(deployerPrivateKey);

        IERC20(token).approve(fortunaAddress, amount);
        fortuna.deposit(token, amount);

        console.log("Deposited", amount, "of", token);
        vm.stopBroadcast();
    }

    // === View Functions ===

    function getClaimFeePercent() public view {
        uint256 percent = fortuna.claimFeePercent();
        console.log("Claim fee percent:", percent);
    }

    function getFeeWallet() public view {
        address feeWallet = fortuna.feeWallet();
        console.log("Fee wallet:", feeWallet);
    }

    function getOperateAddress() public view {
        bool hasOperate = fortuna.hasOperatorRole(operateAddress);
        console.log("Operator has role:", hasOperate);
    }

    function checkPancakeSwapSetup(address token) public view {
        (bool isSupported, address pairedToken, uint256 buyFeePercent, bool buySupported) =
            fortuna.pancakeSwapInfos(token);

        console.log("Token supported:", isSupported);
        console.log("Paired token:", pairedToken);
        console.log("Buy fee percent:", buyFeePercent);
        console.log("Buy supported:", buySupported);
    }

    function getTokenBalance(address token, address user) public view {
        uint256 balance = IERC20(token).balanceOf(user);
        console.log("Token balance for", user, ":", balance);
    }

    function getPancakeRouterAddress() public view {
        address routerAddress = address(fortuna.pancakeRouter());
        console.log("PancakeSwap Router:", routerAddress);
    }
}

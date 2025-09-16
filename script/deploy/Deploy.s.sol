// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../ConfigurableScript.s.sol";
import "../../src/AGT.sol";
import "../../src/FUSD.sol";
import "../../src/NodeCard.sol";
import "../../src/mock/mockUsdt.sol";
import "../../src/interfaces/IPancakeRouter02.sol";
import "../../src/interfaces/IPancakeFactory.sol";
import "../../src/Treasury.sol";
import "../../src/Fortuna.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ConfigTools} from "../ScriptTools.sol";

contract Deploy is ConfigurableScript {
    using ConfigTools for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("BSC_DEPLOY_SECRET_KEY");
        address deployAddr = vm.addr(deployerPrivateKey);
        address proxyAdmin = deployAddr;

        // Read configuration
        uint256 agtInitialSupply = stdJson.readUint(config, ".tokens.agt.initialSupply");
        uint256 fusdInitialSupply = stdJson.readUint(config, ".tokens.fusd.initialSupply");

        address v2Router = stdJson.readAddress(config, ".pancakeswap.router");
        address v2factory = stdJson.readAddress(config, ".pancakeswap.factory");

        address oracle = stdJson.readAddress(config, ".addresses.oracle");
        address vault = stdJson.readAddress(config, ".addresses.vault");
        address team = stdJson.readAddress(config, ".addresses.team");
        address nodeCardTaxWallet = stdJson.readAddress(config, ".tokens.agt.nodeCardTaxWallet");
        address distributeAddress = stdJson.readAddress(config, ".addresses.distributeAddress");
        address operateAddress = stdJson.readAddress(config, ".addresses.operateAddress");

        uint256 minDeposit = stdJson.readUint(config, ".fortuna.minDeposit");
        uint256 feePercent = stdJson.readUint(config, ".fortuna.feePercent");
        uint256 claimFeePercent = stdJson.readUint(config, ".fortuna.claimFeePercent");

        // Liquidity amounts
        uint256 fusdLiquidityAmount = stdJson.readUint(config, ".liquidity.fusdUsdt.fusdAmount") * 1e18;
        uint256 usdtLiquidityAmount = stdJson.readUint(config, ".liquidity.fusdUsdt.usdtAmount") * 1e18;
        uint256 agtLiquidityAmount = stdJson.readUint(config, ".liquidity.fusdAgt.agtAmount") * 1e18;
        uint256 fusdAgtLiquidityAmount = stdJson.readUint(config, ".liquidity.fusdAgt.fusdAmount") * 1e18;

        // Treasury fees (support decimal strings in JSON)
        uint256 depositFeeRate = ConfigTools.parseWad(stdJson.readString(config, ".treasury.basePrice"));
        uint256 withdrawFeeRate = ConfigTools.parseWad(stdJson.readString(config, ".treasury.upPrice"));
        uint256 swapFeeRate = ConfigTools.parseWad(stdJson.readString(config, ".treasury.downPrice"));

        // Fee settings
        uint256 usdtBuyFee = stdJson.readUint(config, ".fees.usdtBuyFee");

        IPancakeRouter02 route = IPancakeRouter02(v2Router);
        IPancakeFactory factory = IPancakeFactory(v2factory);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy or use existing USDT
        address usdtAddress;
        if (vm.envBool("M-USDT")) {
            // BSC Testnet
            MockUsdt usdt = new MockUsdt(agtInitialSupply * 1e20);
            usdtAddress = address(usdt);
            console.log("Deployed Mock USDT:", usdtAddress);
        } else {
            usdtAddress = stdJson.readAddress(config, ".contracts.existingUsdt");
            console.log("Using existing USDT:", usdtAddress);
        }

        // Deploy AGT
        AGT agt = new AGT(agtInitialSupply, nodeCardTaxWallet);
        console.log("AGT deployed at:", address(agt));

        // Deploy FUSD
        FUSD fusd = new FUSD(team, fusdInitialSupply, nodeCardTaxWallet);
        console.log("FUSD deployed at:", address(fusd));

        // Deploy NodeCard proxy
        address nodeCardProxy = Upgrades.deployTransparentProxy(
            "NodeCard.sol:NodeCard", proxyAdmin, abi.encodeCall(NodeCard.initialize, (oracle, vault))
        );
        NodeCard nodeCard = NodeCard(payable(nodeCardProxy));
        console.log("NodeCard proxy deployed at:", nodeCardProxy);

        // Setup initial permissions
        agt.addToWhitelist(address(nodeCard), true);
        fusd.setOperator(deployAddr, true);
        fusd.addToWhitelist(v2Router);
        fusd.addToWhitelist(deployAddr);

        // Approve tokens for liquidity
        if (block.chainid == 97) {
            MockUsdt(usdtAddress).approve(v2Router, agtInitialSupply * 1e18);
        }
        fusd.approve(v2Router, agtInitialSupply * 1e18);
        agt.approve(v2Router, agtInitialSupply * 1e18);

        // Create trading pairs
        address fusdUsdtPair = factory.createPair(address(fusd), usdtAddress);
        fusd.setSwapPair(fusdUsdtPair, true);
        console.log("FUSD<>USDT pair:", fusdUsdtPair);

        address agtFusdPair = factory.createPair(address(fusd), address(agt));
        agt.setSwapPair(agtFusdPair, true);
        fusd.setSwapPair(agtFusdPair, true);
        fusd.setAgtPair(agtFusdPair);
        fusd.addToWhitelist(agtFusdPair);
        console.log("FUSD<>AGT pair:", agtFusdPair);

        // Add liquidity
        route.addLiquidity(
            address(fusd),
            usdtAddress,
            fusdLiquidityAmount,
            usdtLiquidityAmount,
            0,
            0,
            deployAddr,
            block.timestamp + 1000
        );
        console.log("Added FUSD/USDT liquidity");

        route.addLiquidity(
            address(fusd),
            address(agt),
            fusdAgtLiquidityAmount,
            agtLiquidityAmount,
            0,
            0,
            deployAddr,
            block.timestamp + 1000
        );
        console.log("Added FUSD/AGT liquidity");

        // Deploy Treasury proxy
        address treasuryProxy = Upgrades.deployTransparentProxy(
            "Treasury.sol:Treasury",
            proxyAdmin,
            abi.encodeCall(
                Treasury.initialize,
                (address(fusd), usdtAddress, depositFeeRate, withdrawFeeRate, swapFeeRate, v2Router, fusdUsdtPair)
            )
        );
        Treasury treasury = Treasury(payable(treasuryProxy));
        console.log("Treasury proxy deployed at:", treasuryProxy);

        // Setup Treasury permissions
        fusd.addToWhitelist(address(treasury));
        fusd.setFeeExempt(address(treasury), true);
        fusd.transfer(address(treasury), 120000000 * 1e18);
        agt.setFeeExempt(address(treasury), true);

        // Deploy Fortuna proxy
        address[] memory gameTokens = new address[](1);
        uint256[] memory minDeposits = new uint256[](1);
        gameTokens[0] = address(fusd);
        minDeposits[0] = minDeposit;

        address fortunaProxy = Upgrades.deployTransparentProxy(
            "Fortuna.sol:Fortuna",
            proxyAdmin,
            abi.encodeCall(
                Fortuna.initialize,
                (
                    gameTokens,
                    minDeposits,
                    oracle,
                    vault,
                    feePercent,
                    distributeAddress,
                    v2Router,
                    usdtAddress,
                    address(treasury),
                    address(fusd),
                    address(agt),
                    claimFeePercent
                )
            )
        );
        Fortuna fortuna = Fortuna(payable(fortunaProxy));
        console.log("Fortuna proxy deployed at:", fortunaProxy);

        // Setup Fortuna permissions and configuration
        fortuna.setFeeWallet(vault);
        agt.setGameContract(address(fortuna));
        fortuna.grantOperatorRole(operateAddress);
        fortuna.setAgt(address(agt));
        fusd.setOperator(address(fortuna), true);
        agt.addToWhitelist(address(fortuna), true);
        fusd.addToWhitelist(address(fortuna));
        treasury.setOperator(address(fortuna));
        fusd.updateGameContract(address(fortuna));

        // Add additional tokens and configure
        fortuna.addToken(usdtAddress, minDeposit);
        console.log("Added USDT to Fortuna");

        fortuna.addToken(address(agt), minDeposit);
        console.log("Added AGT to Fortuna");

        // Setup PancakeSwap infos
        fortuna.addPancakeSwapInfos(usdtAddress, address(fusd));
        console.log("Added USDT<>FUSD swap info");

        fortuna.addPancakeSwapInfos(address(fusd), address(agt));
        console.log("Added FUSD<>AGT swap info");

        // Set fees
        fortuna.setBuyFee(usdtAddress, true, usdtBuyFee);
        console.log("Set USDT buy fee");

        fortuna.setWithdrawable(address(fusd), false);
        console.log("Set FUSD as non-withdrawable");

        // Export contract addresses for other scripts
        ConfigTools.exportContract("deploy", "usdt", usdtAddress);
        ConfigTools.exportContract("deploy", "agt", address(agt));
        ConfigTools.exportContract("deploy", "fusd", address(fusd));
        ConfigTools.exportContract("deploy", "nodeCard", nodeCardProxy);
        ConfigTools.exportContract("deploy", "treasury", treasuryProxy);
        ConfigTools.exportContract("deploy", "fortuna", fortunaProxy);
        ConfigTools.exportContract("deploy", "fusdUsdtPair", fusdUsdtPair);
        ConfigTools.exportContract("deploy", "agtFusdPair", agtFusdPair);

        console.log("\n=== Deployment Summary ===");
        console.log("Deployer address:", deployAddr);
        console.log("USDT:", usdtAddress);
        console.log("AGT:", address(agt));
        console.log("FUSD:", address(fusd));
        console.log("FUSD/USDT Pair:", fusdUsdtPair);
        console.log("AGT/FUSD Pair:", agtFusdPair);
        console.log("NodeCard proxy at:", nodeCardProxy);
        console.log("NodeCard implementation at:", Upgrades.getImplementationAddress(nodeCardProxy));
        console.log("Treasury proxy at:", treasuryProxy);
        console.log("Treasury implementation at:", Upgrades.getImplementationAddress(treasuryProxy));
        console.log("Fortuna proxy address:", address(fortuna));
        console.log("Fortuna implementation deployed to:", Upgrades.getImplementationAddress(fortunaProxy));
        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../ConfigurableScript.s.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ConfigTools} from "../ScriptTools.sol";

contract Upgrade is ConfigurableScript {
    using ConfigTools for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("BSC_DEPLOY_SECRET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Load addresses from config
        string memory addressesConfig = ConfigTools.loadConfig("addresses");

        address nodeCardProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.nodeCard");
        address treasuryProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.treasury");
        address fortunaProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.fortuna");

        console.log("=== Upgrading Contracts ===");

        // Upgrade NodeCard if needed
        if (nodeCardProxy != address(0)) {
            upgradeNodeCard(nodeCardProxy);
        }

        // Upgrade Treasury if needed
        if (treasuryProxy != address(0)) {
            upgradeTreasury(treasuryProxy);
        }

        // Upgrade Fortuna if needed
        if (fortunaProxy != address(0)) {
            upgradeFortuna(fortunaProxy);
        }

        vm.stopBroadcast();
    }

    function upgradeNodeCard(address proxy) public {
        vm.startBroadcast(vm.envUint("BSC_DEPLOY_SECRET_KEY"));

        console.log("Upgrading NodeCard proxy:", proxy);

        Upgrades.upgradeProxy(proxy, "NodeCard.sol:NodeCard", "");

        address newImplementation = Upgrades.getImplementationAddress(proxy);
        console.log("NodeCard upgraded to implementation:", newImplementation);

        ConfigTools.exportContract("upgrade", "nodeCardImplementation", newImplementation);

        vm.stopBroadcast();
    }

    function upgradeTreasury(address proxy) public {
        vm.startBroadcast(vm.envUint("BSC_DEPLOY_SECRET_KEY"));

        console.log("Upgrading Treasury proxy:", proxy);

        Upgrades.upgradeProxy(proxy, "Treasury.sol:Treasury", "");

        address newImplementation = Upgrades.getImplementationAddress(proxy);
        console.log("Treasury upgraded to implementation:", newImplementation);

        ConfigTools.exportContract("upgrade", "treasuryImplementation", newImplementation);

        vm.stopBroadcast();
    }

    function upgradeFortuna(address proxy) public {
        vm.startBroadcast(vm.envUint("BSC_DEPLOY_SECRET_KEY"));

        console.log("Upgrading Fortuna proxy:", proxy);

        Upgrades.upgradeProxy(proxy, "Fortuna.sol:Fortuna", "");

        address newImplementation = Upgrades.getImplementationAddress(proxy);
        console.log("Fortuna upgraded to implementation:", newImplementation);

        ConfigTools.exportContract("upgrade", "fortunaImplementation", newImplementation);

        vm.stopBroadcast();
    }

    // Individual upgrade functions for specific use cases

    function upgradeNodeCardOnly() external {
        string memory addressesConfig = ConfigTools.loadConfig("addresses");
        address nodeCardProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.nodeCard");

        require(nodeCardProxy != address(0), "NodeCard proxy address not found");
        upgradeNodeCard(nodeCardProxy);
    }

    function upgradeTreasuryOnly() external {
        string memory addressesConfig = ConfigTools.loadConfig("addresses");
        address treasuryProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.treasury");

        require(treasuryProxy != address(0), "Treasury proxy address not found");
        upgradeTreasury(treasuryProxy);
    }

    function upgradeFortunaOnly() external {
        string memory addressesConfig = ConfigTools.loadConfig("addresses");
        address fortunaProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.fortuna");

        require(fortunaProxy != address(0), "Fortuna proxy address not found");
        upgradeFortuna(fortunaProxy);
    }

    // View functions to check implementation addresses

    function checkImplementations() external view {
        string memory addressesConfig = ConfigTools.loadConfig("addresses");

        address nodeCardProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.nodeCard");
        address treasuryProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.treasury");
        address fortunaProxy = stdJson.readAddress(addressesConfig, ".deployedContracts.fortuna");

        console.log("=== Current Implementation Addresses ===");

        if (nodeCardProxy != address(0)) {
            address nodeCardImpl = Upgrades.getImplementationAddress(nodeCardProxy);
            console.log("NodeCard Proxy:", nodeCardProxy);
            console.log("NodeCard Implementation:", nodeCardImpl);
        }

        if (treasuryProxy != address(0)) {
            address treasuryImpl = Upgrades.getImplementationAddress(treasuryProxy);
            console.log("Treasury Proxy:", treasuryProxy);
            console.log("Treasury Implementation:", treasuryImpl);
        }

        if (fortunaProxy != address(0)) {
            address fortunaImpl = Upgrades.getImplementationAddress(fortunaProxy);
            console.log("Fortuna Proxy:", fortunaProxy);
            console.log("Fortuna Implementation:", fortunaImpl);
        }
    }

    function getImplementationAddress(address proxy) external view returns (address) {
        return Upgrades.getImplementationAddress(proxy);
    }

    function getAdminAddress(address proxy) external view returns (address) {
        return Upgrades.getAdminAddress(proxy);
    }
}

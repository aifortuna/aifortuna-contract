// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../ConfigurableScript.s.sol";
import "../../src/AGT.sol";
import "../../src/FUSD.sol";
import "../../src/NodeCard.sol";
import "../../src/Treasury.sol";
import "../../src/Fortuna.sol";
import "../../src/interfaces/IPancakeRouter02.sol";
import {ConfigTools} from "../ScriptTools.sol";

contract InteractionBase is ConfigurableScript {
    using ConfigTools for string;

    // Contract instances
    AGT public agt;
    FUSD public fusd;
    NodeCard public nodeCard;
    Treasury public treasury;
    Fortuna public fortuna;
    IPancakeRouter02 public pancakeRouter;

    // Contract addresses
    address public usdtAddress;
    address public agtAddress;
    address public fusdAddress;
    address public nodeCardAddress;
    address public treasuryAddress;
    address public fortunaAddress;

    // Key addresses
    address public oracle;
    address public vault;
    address public team;
    address public distributeAddress;
    address public operateAddress;
    address public feeAddress;

    uint256 public deployerPrivateKey;
    uint256 public oraclePrivateKey;
    address public deployerAddress;

    function setUp() public override {
        super.setUp();

        deployerPrivateKey = vm.envUint("BSC_DEPLOY_SECRET_KEY");
        oraclePrivateKey = vm.envUint("ORACLE_SECRET_KEY");
        deployerAddress = vm.addr(deployerPrivateKey);

        // Load addresses from config
        string memory addressesConfig = ConfigTools.loadConfig("addresses");

        usdtAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.usdt");
        agtAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.agt");
        fusdAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.fusd");
        nodeCardAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.nodeCard");
        treasuryAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.treasury");
        fortunaAddress = stdJson.readAddress(addressesConfig, ".deployedContracts.fortuna");

        oracle = stdJson.readAddress(addressesConfig, ".operators.oracle");
        vault = stdJson.readAddress(addressesConfig, ".operators.vault");
        team = stdJson.readAddress(addressesConfig, ".operators.team");
        distributeAddress = stdJson.readAddress(addressesConfig, ".operators.distributeAddress");
        operateAddress = stdJson.readAddress(addressesConfig, ".operators.operateAddress");
        feeAddress = stdJson.readAddress(addressesConfig, ".operators.feeAddress");

        // Initialize contract instances
        if (agtAddress != address(0)) {
            agt = AGT(agtAddress);
        }
        if (fusdAddress != address(0)) {
            fusd = FUSD(fusdAddress);
        }
        if (nodeCardAddress != address(0)) {
            nodeCard = NodeCard(payable(nodeCardAddress));
        }
        if (treasuryAddress != address(0)) {
            treasury = Treasury(payable(treasuryAddress));
        }
        if (fortunaAddress != address(0)) {
            fortuna = Fortuna(payable(fortunaAddress));
            pancakeRouter = fortuna.pancakeRouter();
        }

        console.log("\n=== Interaction Setup ===");
        console.log("Deployer:", deployerAddress);
        console.log("USDT:", usdtAddress);
        console.log("AGT:", agtAddress);
        console.log("FUSD:", fusdAddress);
        console.log("NodeCard:", nodeCardAddress);
        console.log("Treasury:", treasuryAddress);
        console.log("Fortuna:", fortunaAddress);
    }

    // Helper function to create oracle signature
    function createOracleSignature(
        address user,
        address token,
        uint256 amount,
        string memory signContext,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 message = keccak256(abi.encodePacked(user, token, amount, signContext, deadline));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // Helper function to get current timestamp + offset
    function getDeadline(uint256 offsetSeconds) internal view returns (uint256) {
        return block.timestamp + offsetSeconds;
    }

    // Helper function to create sign context
    function createSignContext(string memory prefix) internal view returns (string memory) {
        return string(abi.encodePacked(prefix, "_", vm.toString(block.timestamp), "_", vm.toString(deployerAddress)));
    }
}

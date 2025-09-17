// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/IPancakeRouter02.sol";

event NodeCardPurchased(
    address indexed user,
    address[] tokenAddrList,
    uint256[] tokenAmountList,
    uint256 bnbAmount,
    uint256 timestamp,
    string purchaseContext,
    bytes signature
);

event NodeCardInitialized(
    address indexed owner, address indexed oracle, address indexed vault, uint256 bnbFee, uint256 timestamp
);

event NodeCardOracleUpdated(address indexed operator, address oldOracle, address newOracle, uint256 timestamp);

event NodeCardVaultUpdated(address indexed operator, address oldVault, address newVault, uint256 timestamp);

event NodeCardBnbFeeUpdated(address indexed operator, uint256 oldFee, uint256 newFee, uint256 timestamp);

event NodeCardEmergencyWithdrawal(address indexed operator, address indexed token, uint256 amount, uint256 timestamp);

contract NodeCard is Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    address public oracle;
    address public vault;
    uint256 public bnb_fee;

    uint256 public constant BPS = 10000;

    mapping(string => bool) public usedPurchaseContexts;

    address public _slot0;
    address public _slot1;
    address public _slot2;
    address public _slot3;
    address public _slot4;
    address public _slot5;
    uint256 public _slot6;
    uint256 public _slot7;
    uint256 public _slot8;
    uint256 public _slot9;
    uint256 public _slot10;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _oracle, address _vault) external initializer {
        __Ownable_init(_msgSender());
        __Ownable2Step_init();

        require(_oracle != address(0), "Oracle address cannot be zero");
        require(_vault != address(0), "Vault address cannot be zero");
        oracle = _oracle;
        vault = _vault;

        bnb_fee = 0.0002 ether; // 0.0002 BNB
        //claimFeePercent = 5000; // 50%
        // pancakeRouter = IPancakeRouter02(_pancakeRouter);

        emit NodeCardInitialized(msg.sender, _oracle, _vault, bnb_fee, block.timestamp);
    }

    function purchase(
        address[] memory tokenAddrList,
        uint256[] memory tokenAmountList,
        uint256 deadline,
        string memory purchaseContext,
        bytes memory signature
    ) external payable {
        require(tokenAddrList.length == tokenAmountList.length, "Arrays length mismatch");
        require(tokenAddrList.length > 0, "Token list cannot be empty");
        require(block.timestamp <= deadline, "Transaction expired");
        require(msg.value >= bnb_fee, "Insufficient BNB fee");
        require(!usedPurchaseContexts[purchaseContext], "Purchase context already used");

        bytes32 message =
            keccak256(abi.encodePacked(msg.sender, tokenAddrList, tokenAmountList, purchaseContext, deadline));
        require(signature.length == 65, "bad sig length");
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        require(oracle == recovered, "Invalid oracle signature");

        for (uint256 i = 0; i < tokenAddrList.length; i++) {
            require(tokenAddrList[i] != address(0), "Token address cannot be zero");
            require(tokenAmountList[i] > 0, "Token amount must be greater than zero");

            IERC20(tokenAddrList[i]).safeTransferFrom(msg.sender, vault, tokenAmountList[i]);
        }

        (bool success,) = vault.call{value: bnb_fee}("");
        require(success, "BNB transfer failed");

        if (msg.value > bnb_fee) {
            (bool refundSuccess,) = msg.sender.call{value: msg.value - bnb_fee}("");
            require(refundSuccess, "BNB refund failed");
        }

        usedPurchaseContexts[purchaseContext] = true;
        emit NodeCardPurchased(
            msg.sender, tokenAddrList, tokenAmountList, bnb_fee, block.timestamp, purchaseContext, signature
        );
    }

    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "Oracle address cannot be zero");
        address oldOracle = oracle;
        oracle = _oracle;
        emit NodeCardOracleUpdated(msg.sender, oldOracle, _oracle, block.timestamp);
    }

    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "Vault address cannot be zero");
        address oldVault = vault;
        vault = _vault;
        emit NodeCardVaultUpdated(msg.sender, oldVault, _vault, block.timestamp);
    }

    function setBnbFee(uint256 _bnbFee) external onlyOwner {
        uint256 oldFee = bnb_fee;
        bnb_fee = _bnbFee;
        emit NodeCardBnbFeeUpdated(msg.sender, oldFee, _bnbFee, block.timestamp);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            // 提取BNB
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "BNB withdrawal failed");
        } else {
            // 提取ERC20代币
            IERC20(token).safeTransfer(msg.sender, amount);
        }
        emit NodeCardEmergencyWithdrawal(msg.sender, token, amount, block.timestamp);
    }

    receive() external payable {}
}

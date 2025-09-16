// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AGT Token (Utility)
/// @notice Large supply utility/burn/fee token. Initial supply minted to owner; burn & fee logic can be added later.
contract AGT is ERC20, Ownable, ReentrancyGuard {
    mapping(address => bool) public feeExempt;
    mapping(address => bool) public swapPairs; // addresses treated as AMM pairs / routers triggering fee
    mapping(address => bool) public whitelist;

    address public feeWallet; // receives trade fees
    address public gameContract; // receives CardFee fees
    uint256 public feeBps = 1000; // 10% default (basis points)
    uint256 public constant BPS = 10000; // 100% in basis points
    uint256 public gameFeeBps;

    event FeeReceived(address indexed from, address indexed feeWallet, uint256 amount);
    event OperatorRoleRevoked(address indexed operator, address indexed account, uint256 timestamp);
    event OperatorRoleGranted(address indexed operator, address indexed account, uint256 timestamp);
    event GameContractUpdate(address indexed newContract, address oldContract);
    event FeeExemptUpdated(address indexed account, bool status);
    event SwapPairUpdated(address indexed pair, bool status);
    event FeeWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event GameFeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event NodeCardFeeReceived(address indexed from, address indexed feeWallet, uint256 amount);
    event AGTInitialized(address indexed owner, uint256 initialSupply, uint256 timestamp);
    event WhitelistUpdated(address indexed account, bool status);
    event RoleUpdated(address indexed newAdmin, address indexed oldAdmin);

    constructor(uint256 initialSupply, address _feeWallet) ERC20("AIFortuna Game Token", "AGT") Ownable(msg.sender) {
        uint256 mintAmount = initialSupply * 10 ** decimals();
        _mint(msg.sender, mintAmount);
        feeExempt[msg.sender] = true;
        feeWallet = _feeWallet;

        gameFeeBps = 9000;

        emit AGTInitialized(msg.sender, mintAmount, block.timestamp);
        emit FeeWalletUpdated(address(0), _feeWallet);
    }

    function _calculateFees(uint256 totalFee) internal view returns (uint256 gameFee, uint256 teamFee) {
        gameFee = (totalFee * gameFeeBps) / BPS;
        teamFee = totalFee - gameFee;
    }

    function setFeeExempt(address a, bool s) external onlyOwner {
        feeExempt[a] = s;
        emit FeeExemptUpdated(a, s);
    }

    function setSwapPair(address pair, bool status) external onlyOwner {
        swapPairs[pair] = status;
        emit SwapPairUpdated(pair, status);
    }

    function setFeeWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "op zero");
        emit FeeWalletUpdated(feeWallet, wallet);
        feeWallet = wallet;
        feeExempt[wallet] = true; // auto exempt fee wallet
        emit FeeExemptUpdated(wallet, true);
    }

    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "fee > denom");
        emit FeeBpsUpdated(feeBps, newFeeBps);
        feeBps = newFeeBps;
    }

    function setGameFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= BPS, "fee > denom");
        emit GameFeeBpsUpdated(gameFeeBps, newFeeBps);
        gameFeeBps = newFeeBps;
    }

    function setGameContract(address _gameContract) external onlyOwner {
        address old_cnt = gameContract;
        gameContract = _gameContract;

        emit GameContractUpdate(_gameContract, old_cnt);
    }

    /**
     * @dev Add address to whitelist
     * @param account Address to add to whitelist
     */
    function addToWhitelist(address account, bool status) external onlyOwner {
        require(account != address(0), "Cannot whitelist zero address");
        whitelist[account] = status;
        emit WhitelistUpdated(account, status);
    }

    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        return _transferWithFee(_msgSender(), to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override nonReentrant returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        return _transferWithFee(from, to, amount);
    }

    function _transferWithFee(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0) && to != address(0), "zero addr");
        uint256 fee = 0;

        if (is_sell(from, to)) {
            // Selling AGT to pair (AGT -> FUSD), allow anyone, charge AGT fee
            if (feeBps > 0) {
                fee = (amount * feeBps) / BPS;
            }
        } else if (is_buy(from, to)) {
            // Buying AGT from pair (FUSD -> AGT), check whitelist and charge fee
            require(whitelist[to], "not whitelisted");
        }

        if (fee > 0) {
            uint256 sendAmount = amount - fee;
            super._transfer(from, to, sendAmount);

            (uint256 gameFee, uint256 teamFee) = _calculateFees(fee);

            super._transfer(from, feeWallet, teamFee);
            super._transfer(from, gameContract, gameFee);

            emit NodeCardFeeReceived(from, gameContract, gameFee);
            emit FeeReceived(from, feeWallet, teamFee);
        } else {
            super._transfer(from, to, amount);
        }
        return true;
    }

    function is_sell(address from, address to) public view returns (bool) {
        return swapPairs[to] && !feeExempt[from] && !feeExempt[to];
    }

    function is_buy(address from, address to) public view returns (bool) {
        return swapPairs[from] && !feeExempt[from] && !feeExempt[to];
    }

    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "zero amount");
        _burn(_msgSender(), amount);
    }
}

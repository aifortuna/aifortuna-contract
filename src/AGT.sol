// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AGT is ERC20, Ownable, ReentrancyGuard {
    mapping(address => bool) public feeExempt;
    mapping(address => bool) public swapPairs;
    mapping(address => bool) public whitelist;

    address public feeWallet;
    address public gameContract;
    uint256 public feeBps = 1000;
    uint256 public constant BPS = 10000;
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
        feeExempt[_feeWallet] = true;

        gameFeeBps = 9000;

        emit AGTInitialized(msg.sender, mintAmount, block.timestamp);
        emit FeeWalletUpdated(address(0), _feeWallet);
        emit FeeExemptUpdated(msg.sender, true);
        emit FeeExemptUpdated(_feeWallet, true);
    }

    function _calculateFees(uint256 totalFee) internal view returns (uint256 gameFee, uint256 teamFee) {
        if (gameContract == address(0)) {
            gameFee = 0;
            teamFee = 0;
        } else {
            gameFee = (totalFee * gameFeeBps) / BPS;
            teamFee = totalFee - gameFee;
        }
    }

    function setFeeExempt(address a, bool s) external onlyOwner {
        require(feeExempt[a] != s, "Value unchanged");
        feeExempt[a] = s;
        emit FeeExemptUpdated(a, s);
    }

    function setSwapPair(address pair, bool status) external onlyOwner {
        require(swapPairs[pair] != status, "Value unchanged");
        swapPairs[pair] = status;
        emit SwapPairUpdated(pair, status);
    }

    function setFeeWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "op zero");
        require(feeWallet != wallet, "Value unchanged");

        address oldWallet = feeWallet;
        feeWallet = wallet;
        emit FeeWalletUpdated(oldWallet, wallet);

        if (oldWallet != address(0) && feeExempt[oldWallet]) {
            feeExempt[oldWallet] = false;
            emit FeeExemptUpdated(oldWallet, false);
        }

        feeExempt[wallet] = true;
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
        require(_gameContract != address(0), "zero addr");
        require(gameContract != _gameContract, "Value unchanged");

        address old_cnt = gameContract;
        gameContract = _gameContract;

        emit GameContractUpdate(_gameContract, old_cnt);
    }

    function addToWhitelist(address account, bool status) external onlyOwner {
        require(account != address(0), "Cannot whitelist zero address");
        require(whitelist[account] != status, "Value unchanged");

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

        if (is_sell(to) && !isFeeExempt(from, to)) {
            // Selling AGT to pair (AGT -> FUSD), allow anyone, charge AGT fee
            if (feeBps > 0) {
                fee = (amount * feeBps) / BPS;
            }
        } else if (is_buy(from) && !isFeeExempt(from, to)) {
            // Buying AGT from pair (FUSD -> AGT) Only Check whitelist, no fee
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

    function is_sell(address to) public view returns (bool) {
        return swapPairs[to];
    }

    function is_buy(address from) public view returns (bool) {
        return swapPairs[from];
    }

    function isFeeExempt(address from, address to) public view returns (bool) {
        return feeExempt[from] || feeExempt[to];
    }

    function burn(uint256 amount) external nonReentrant {
        require(amount > 0, "zero amount");
        _burn(_msgSender(), amount);
    }
}

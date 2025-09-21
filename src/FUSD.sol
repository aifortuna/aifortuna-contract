// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FUSD is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public team;
    address public gameContract;

    mapping(address => bool) public swapPairs;

    address public agtSwapPair;

    uint256 public gameFeeBps = 9000;
    uint256 public feeBps = 1000;
    uint256 public agt_pair_feeBps = 1000;

    uint256 public constant FEE_DENOMINATOR = 10000;

    bool public isOpenSellWhitelist = false;
    bool public isOpenBuyWhitelist = false;

    mapping(address => bool) public whitelist;
    mapping(address => bool) public feeExempt;
    mapping(address => bool) public minters;
    mapping(address => bool) public operators;

    // Events
    event WhitelistUpdated(address indexed account, bool status);
    event FeeBpsUpdated(uint256 fee, bool status);
    event AGTFeeBpsUpdated(uint256 fee, bool status);

    event TeamUpdated(address indexed oldTeam, address indexed newTeam);
    event FeeExemptUpdated(address indexed account, bool status);
    event MinterUpdated(address indexed account, bool status);
    event OperatorUpdated(address indexed account, bool status);
    event GameFeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    event FeeReceived(address indexed from, address indexed feeWallet, uint256 amount);
    event NodeCardFeeReceived(address indexed from, address indexed feeWallet, uint256 amount);
    event SwapPairUpdated(address indexed pair, bool status);
    event AgtPairUpdated(address indexed pair);
    event TokensMinted(address indexed to, uint256 amount, address indexed minter, uint256 timestamp);
    event TokensBurned(address indexed from, uint256 amount, uint256 timestamp);
    event FUSDInitialized(address indexed owner, address indexed team, uint256 initialSupply, uint256 timestamp);
    event TokensRecovered(address indexed token, address indexed to, uint256 amount, uint256 timestamp);
    event ETHRecovered(address indexed to, uint256 amount, uint256 timestamp);
    event FeeWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event GameContractUpdated(address indexed oldContract, address indexed newContract);

    event WhiteListStatusUpdated(bool buy, bool sell);

    /**
     * @dev Constructor
     * @param _team Team wallet address
     * @param _initialSupply Initial token supply
     */
    constructor(address _team, uint256 _initialSupply, address _gameContract)
        ERC20("Fortuna USD", "FUSD")
        Ownable(msg.sender)
    {
        whitelist[msg.sender] = true;
        whitelist[_team] = true;
        feeExempt[msg.sender] = true;
        feeExempt[_team] = true;

        uint256 mintAmount = _initialSupply * 10 ** decimals();
        _mint(msg.sender, mintAmount);
        setOperator(msg.sender, true);
        team = _team;
        gameContract = _gameContract;
        gameFeeBps = 9000;
        isOpenBuyWhitelist = true;
        isOpenSellWhitelist = false;

        emit FUSDInitialized(msg.sender, _team, mintAmount, block.timestamp);
        emit TokensMinted(msg.sender, mintAmount, msg.sender, block.timestamp);
        emit WhitelistUpdated(msg.sender, true);
        emit WhitelistUpdated(_team, true);
        emit FeeExemptUpdated(msg.sender, true);
        emit FeeExemptUpdated(_team, true);
    }

    modifier onlyMinter() {
        require(minters[msg.sender], "Not minter");
        _;
    }

    modifier onlyOperators() {
        require(operators[msg.sender], "Not operators");
        _;
    }

    function _calculateFees(uint256 totalFee) internal view returns (uint256 gameFee, uint256 teamFee) {
        gameFee = (totalFee * gameFeeBps) / FEE_DENOMINATOR;
        teamFee = totalFee - gameFee;
    }

    /**
     * @dev Set or unset a minter address
     */
    function setMinter(address account, bool status) external onlyOwner {
        require(account != address(0), "zero addr");
        minters[account] = status;
        emit MinterUpdated(account, status);
    }

    /**
     * @dev Set or unset a operators  address
     */
    function setOperator(address account, bool status) public onlyOwner {
        require(account != address(0), "zero addr");
        operators[account] = status;
        emit OperatorUpdated(account, status);
    }

    /**
     * @dev Set or unset a operators  address
     */
    function setWhitelist(bool buy, bool sell) public onlyOwner {
        isOpenBuyWhitelist = buy;
        isOpenSellWhitelist = sell;
        emit WhiteListStatusUpdated(buy, sell);
    }

    /**
     * @dev Mint new tokens (governed / Team / proxy controlled)
     */
    function mint(address to, uint256 amount) external onlyMinter nonReentrant {
        _mint(to, amount);
        emit TokensMinted(to, amount, msg.sender, block.timestamp);
    }

    function burn(uint256 amount) external nonReentrant {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Override transfer function to implement whitelist and fee logic
     */
    function transfer(address to, uint256 amount) public override nonReentrant returns (bool) {
        return _transferWithFee(msg.sender, to, amount);
    }

    /**
     * @dev Override transferFrom function to implement whitelist and fee logic
     */
    function transferFrom(address from, address to, uint256 amount) public override nonReentrant returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        return _transferWithFee(from, to, amount);
    }

    function setGameFeeBps(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= FEE_DENOMINATOR, "fee > denom");
        emit GameFeeBpsUpdated(gameFeeBps, newFeeBps);
        gameFeeBps = newFeeBps;
    }

    /**
     * @dev Internal function to handle transfers with fee and whitelist logic
     */
    function _transferWithFee(address from, address to, uint256 amount) internal returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");

        bool isTrade = swapPairs[from] || swapPairs[to];
        uint256 feeAmount = 0;
        uint256 transferAmount = amount;

        if (isTrade && !feeExempt[from] && !feeExempt[to]) {
            if (to == agtSwapPair) {
                //  Buy AGT
                feeAmount = (amount * agt_pair_feeBps) / FEE_DENOMINATOR;
                transferAmount = amount - feeAmount;
            } else if (from == agtSwapPair) {
                // Sell AGT: we chearge fee on AGT side, keep this empty
            } else {
                if (isOpenBuyWhitelist) {
                    require(whitelist[to], "Not whitelisted");
                }

                if (isOpenSellWhitelist) {
                    require(whitelist[from], "Not whitelisted");
                }

                if (swapPairs[to]) {
                    feeAmount = (amount * feeBps) / FEE_DENOMINATOR;
                    transferAmount = amount - feeAmount;
                }
            }
        }

        // Execute the transfer
        _transfer(from, to, transferAmount);

        if (feeAmount > 0) {
            //Sell FUSD for AGT, so trasnfer FUSD to agtSwapPair
            if (to == agtSwapPair) {
                (uint256 gameFee, uint256 teamFee) = _calculateFees(feeAmount);

                _transfer(from, team, teamFee);
                emit FeeReceived(from, team, teamFee);

                _transfer(from, gameContract, gameFee);
                emit NodeCardFeeReceived(from, gameContract, gameFee);
            } else {
                _transfer(from, team, feeAmount);
                emit FeeReceived(from, team, feeAmount);
            }
        }

        return true;
    }

    /**
     * @dev Add address to whitelist
     * @param account Address to add to whitelist
     */
    function addToWhitelist(address account) external onlyOperators {
        require(account != address(0), "Cannot whitelist zero address");
        whitelist[account] = true;
        emit WhitelistUpdated(account, true);
    }

    /**
     * @dev Remove address from whitelist
     * @param account Address to remove from whitelist
     */
    function removeFromWhitelist(address account) external onlyOwner {
        whitelist[account] = false;
        emit WhitelistUpdated(account, false);
    }

    /**
     * @dev Add USDT pair fee
     * @param _fee percentage of tax
     */
    function updateFeeBps(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "fee > denom");
        feeBps = _fee;
        emit FeeBpsUpdated(_fee, true);
    }

    /**
     * @dev Add AGT pair fee
     * @param _fee percentage of agt tax
     */
    function updateAGTFeeBps(uint256 _fee) external onlyOwner {
        require(_fee <= 1000, "fee > denom");
        agt_pair_feeBps = _fee;
        emit AGTFeeBpsUpdated(_fee, true);
    }

    /**
     * @dev Set fee exempt status for an address
     * @param account Address to update fee exempt status
     * @param exempt Fee exempt status
     */
    function setFeeExempt(address account, bool exempt) external onlyOwner {
        feeExempt[account] = exempt;
        emit FeeExemptUpdated(account, exempt);
    }

    /**
     * @dev Update Team address
     * @param _team New Team address
     */
    function updateTeam(address _team) external onlyOwner {
        require(_team != address(0), "Team cannot be zero address");
        address oldTeam = team;
        team = _team;

        // Update whitelist and fee exempt status
        whitelist[_team] = true;
        feeExempt[_team] = true;
        whitelist[oldTeam] = false;
        feeExempt[oldTeam] = false;

        emit WhitelistUpdated(oldTeam, false);
        emit FeeExemptUpdated(oldTeam, false);
        emit TeamUpdated(oldTeam, _team);
        emit WhitelistUpdated(_team, true);
        emit FeeExemptUpdated(_team, true);
    }

    /**
     * @dev Update Game address
     * @param _gameContract New Game address
     */
    function updateGameContract(address _gameContract) external onlyOwner {
        require(_gameContract != address(0), "GameContract cannot be zero address");
        address oldGameContract = gameContract;
        gameContract = _gameContract;

        // Update whitelist and fee exempt status
        whitelist[_gameContract] = true;

        emit GameContractUpdated(oldGameContract, _gameContract);
        emit WhitelistUpdated(_gameContract, true);
    }

    /**
     * @dev Check if an address is whitelisted
     * @param account Address to check
     * @return bool Whitelist status
     */
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account];
    }

    /**
     * @dev Check if an address is fee exempt
     * @param account Address to check
     * @return bool Fee exempt status
     */
    function isFeeExempt(address account) external view returns (bool) {
        return feeExempt[account];
    }

    /**
     * @dev Calculate fee amount for a given transfer amount
     * @param amount Transfer amount
     * @return feeAmount Fee amount
     * @return transferAmount Amount after fee deduction
     */
    function calculateFee(uint256 amount) external view returns (uint256 feeAmount, uint256 transferAmount) {
        feeAmount = (amount * feeBps) / FEE_DENOMINATOR;
        transferAmount = amount - feeAmount;
    }

    /**
     * @dev Emergency function to recover any ERC20 tokens sent to this contract
     * @param token Token address
     * @param amount Amount to recover
     */
    function recoverTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot recover FUSD tokens");
        address recipient = owner();
        IERC20(token).safeTransfer(recipient, amount);
        emit TokensRecovered(token, recipient, amount, block.timestamp);
    }

    function setSwapPair(address pair, bool status) external onlyOwner {
        swapPairs[pair] = status;
        whitelist[pair] = status;
        emit SwapPairUpdated(pair, status);
        emit WhitelistUpdated(pair, status);
    }

    function setAgtPair(address _pair) external onlyOwner {
        agtSwapPair = _pair;
        emit AgtPairUpdated(_pair);
    }
}

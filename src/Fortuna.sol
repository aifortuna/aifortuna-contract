// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/ITreasuryHedge.sol";
import "./interfaces/IFUSD.sol";
import "./interfaces/IAGT.sol";

error InvalidOracleSignature();
error TokenNotSupported();
error AmountZero();
error SignatureExpired();
error SignContextUsed();
error PairedTokenNotSet();
error BuyFeeNotSet();
error OnlySellPathsAllowed();
error InsufficientPairedOutput();

event Deposit(address indexed user, address indexed token, uint256 amount, uint256 timestamp);

event WithdrawRequest(
    address indexed user, address indexed token, uint256 amount, uint256 timestamp, uint256 withdrawId
);

event WithdrawConfirm(
    address indexed operator,
    address indexed user,
    address indexed token,
    uint256 amount,
    uint256 timestamp,
    uint256 withdrawId
);

event WithdrawCancel(
    address indexed operator,
    address indexed user,
    address indexed token,
    uint256 amount,
    uint256 timestamp,
    uint256 withdrawId
);

event DistributeFee(
    address indexed operator,
    address indexed distributeAddress,
    address indexed token,
    uint256 amount,
    uint256 timestamp
);

event AdminWithdraw(address indexed operator, address indexed token, uint256 amount, uint256 timestamp);

event MerkleRootUpdated(address indexed operator, bytes32 oldRoot, bytes32 newRoot, uint256 timestamp);

event TokenAdded(address indexed operator, address indexed token, uint256 minDeposit, uint256 timestamp);

event TokenRemoved(address indexed operator, address indexed token, uint256 timestamp);

event UserTokenAdded(address indexed user, address indexed token, uint256 minDeposit, uint256 fee, uint256 timestamp);

event UserTokenRemoved(address indexed user, address indexed token, uint256 fee, uint256 timestamp);

event UserTokenFeeUpdated(address indexed operator, uint256 oldFee, uint256 newFee, uint256 timestamp);

event PancakeSwapInfoAdded(address indexed user, address indexed token, address pairedToken, uint256 timestamp);

event PairedTokenMinted(
    address indexed user,
    address indexed token,
    uint256 amountIn,
    address pairedTokenAddress,
    uint256 amountOut,
    string signContext,
    bytes signature
);

event PairedTokenRewardsClaimed(
    address indexed user,
    address indexed token,
    uint256 tokenAmountOut,
    address pairedTokenAddress,
    uint256 pairedTokenAmountOut,
    uint256 claimFeePercent,
    string signContext,
    bytes signature
);

event Swap(
    address indexed user, address indexed inputToken, address indexed outputToken, uint256 amountIn, uint256 amountOut
);

event TokenBought(
    address indexed user,
    address indexed token,
    uint256 amountIn,
    address outTokenAddress,
    uint256 tokenAmountOut,
    string signContext,
    bytes signature
);

event FortunaInitialized(
    address indexed owner,
    address[] tokens,
    address oracle,
    address feeWallet,
    uint256 feePercent,
    address distributeAddress,
    address pancakeRouter,
    address usdt,
    address treasuryHedge,
    address fusd,
    address agt,
    uint256 claimFeePercent,
    uint256 timestamp
);

event WithdrawCountUpdated(address indexed operator, uint256 oldCount, uint256 newCount, uint256 timestamp);

event PancakeRouterUpdated(address indexed operator, address oldRouter, address newRouter, uint256 timestamp);

event TokenWithdrawableUpdated(address indexed operator, address indexed token, bool withdrawable, uint256 timestamp);

event BuyFeeUpdated(
    address indexed operator, address indexed token, bool buySupported, uint256 buyFeePercent, uint256 timestamp
);

event MinDepositUpdated(
    address indexed operator, address indexed token, uint256 oldMinDeposit, uint256 newMinDeposit, uint256 timestamp
);

event DistributeAddressUpdated(address indexed operator, address oldAddress, address newAddress, uint256 timestamp);

event OracleUpdated(address indexed operator, address oldOracle, address newOracle, uint256 timestamp);

event AgtUpdated(address indexed operator, address oldAgt, address newAgt, uint256 timestamp);

event FeeWalletUpdated(address indexed operator, address oldWallet, address newWallet, uint256 timestamp);

event FeePercentUpdated(address indexed operator, uint256 oldFeePercent, uint256 newFeePercent, uint256 timestamp);

event ClaimFeePercentUpdated(
    address indexed operator, uint256 oldClaimFeePercent, uint256 newClaimFeePercent, uint256 timestamp
);

event OperatorRoleRevoked(address indexed operator, address indexed account, uint256 timestamp);

event OperatorRoleGranted(address indexed operator, address indexed account, uint256 timestamp);

event TreasuryHedgeUpdated(address indexed operator, address oldTreasury, address newTreasury, uint256 timestamp);

event FusdUpdated(address indexed operator, address oldFusd, address newFusd, uint256 timestamp);

event UsdtUpdated(address indexed operator, address oldUsdt, address newUsdt, uint256 timestamp);

event LpTokenUpdated(address indexed operator, address oldLpToken, address newLpToken, uint256 timestamp);

event BnbFeeUpdated(address indexed operator, uint256 oldFee, uint256 newFee, uint256 timestamp);

event EmergencyWithdrawal(address indexed operator, address indexed token, uint256 amount, uint256 timestamp);

event NodeCardUpdated(address indexed operator, address oldVault, address newVault, uint256 timestamp);

event PairedTokenARewardsClaimed(
    address indexed user,
    address indexed token,
    uint256 tokenAmountOut,
    address pairedTokenAddress,
    uint256 pairedTokenAmountOut,
    uint256 claimFeePercent,
    string signContext,
    bytes signature
);

event PairedTokenBRewardsClaimed(
    address indexed user,
    address indexed token,
    uint256 tokenAmountOut,
    address pairedTokenAddress,
    uint256 pairedTokenAmountOut,
    uint256 claimFeePercent,
    string signContext,
    bytes signature
);

event DailyTokenBurn(
    address indexed user,
    address indexed token,
    uint256 tokenAmountIn,
    address pairedTokenAddress,
    uint256 pairedTokenAmountIn,
    uint256 timestamp,
    uint256 nonce,
    bytes signature
);

contract Fortuna is Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct Withdraw {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool isConfirmed;
        bool isCanceled;
    }

    struct TokenInfo {
        bool isSupported;
        uint256 minDeposit;
        bool withdrawable;
    }

    struct PancakeSwapInfo {
        bool isSupported;
        address pairedToken;
        uint256 buyFeePercent;
        bool buySupported;
    }

    uint256 constant BPS = 10000;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address => TokenInfo) public supportedTokens;
    mapping(address => PancakeSwapInfo) public pancakeSwapInfos;
    IPancakeRouter02 public pancakeRouter;
    address[] public tokenList;
    address public lp_token;
    address public usdt;
    IAGT public agt;
    IFUSD public fusd;
    uint256 public bnb_fee;
    uint256 public hold_fee;

    ITreasuryHedge public treasuryHedge;

    mapping(address => uint256) public totalDeposit; // token => total deposit
    mapping(address => uint256) public totalWithdraw; // token => total withdraw
    mapping(address => uint256) public totalFee; // token => total fee

    uint256 public withdrawCount;

    address public oracle;
    uint256 public oracleNonce;
    address public feeWallet;
    uint256 public feePercent;
    uint256 public claimFeePercent;
    address public distributeAddress;
    bytes32 public merkleRoot;
    uint256 public slippageBps;

    mapping(address => mapping(address => uint256)) public playerDeposit; // user => token => amount
    mapping(address => mapping(address => uint256)) public playerWithdraw; // user => token => amount
    mapping(address => uint256) public playerWithdrawRequest; // user => withdrawId
    mapping(uint256 => Withdraw) public withdraws;
    mapping(string => bool) public usedSignContexts;

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

    function initialize(
        address[] memory _gameTokens,
        uint256[] memory _minDeposits,
        address _oracle,
        address _feeWallet,
        uint256 _feePercent,
        address _distributeAddress,
        address _pancakeRouter,
        address _usdt,
        address _treasuryHedge,
        address _fusd,
        address _agt,
        uint256 _claimFeePercent
    ) external initializer {
        __Ownable_init(_msgSender());
        __Ownable2Step_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        require(_gameTokens.length == _minDeposits.length, "Arrays length mismatch");

        for (uint256 i = 0; i < _gameTokens.length; i++) {
            supportedTokens[_gameTokens[i]] =
                TokenInfo({isSupported: true, minDeposit: _minDeposits[i], withdrawable: true});
            tokenList.push(_gameTokens[i]);
        }

        oracle = _oracle;
        feeWallet = _feeWallet;
        feePercent = _feePercent;
        distributeAddress = _distributeAddress;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        usdt = _usdt;
        agt = IAGT(_agt);
        bnb_fee = 0.00002 ether;
        claimFeePercent = _claimFeePercent;
        hold_fee = 1e16;
        slippageBps = 2000; // 20%

        treasuryHedge = ITreasuryHedge(_treasuryHedge);
        fusd = IFUSD(_fusd);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        withdrawCount = 1;

        emit FortunaInitialized(
            msg.sender,
            _gameTokens,
            _oracle,
            _feeWallet,
            _feePercent,
            _distributeAddress,
            _pancakeRouter,
            _usdt,
            _treasuryHedge,
            _fusd,
            _agt,
            _claimFeePercent,
            block.timestamp
        );
    }

    modifier fundBNB() {
        require(msg.value == bnb_fee, "Insufficient BNB");
        (bool success,) = feeWallet.call{value: bnb_fee}("");
        require(success, "BNB transfer failed");
        _;
    }

    function forceSetWithdrawCount(uint256 _withdrawCount) external onlyOwner {
        uint256 oldCount = withdrawCount;
        withdrawCount = _withdrawCount;
        emit WithdrawCountUpdated(msg.sender, oldCount, _withdrawCount, block.timestamp);
    }

    function deposit(address token, uint256 amount) external nonReentrant {
        if (!supportedTokens[token].isSupported) revert TokenNotSupported();
        require(amount >= supportedTokens[token].minDeposit, "Amount must be greater than minDeposit");

        totalDeposit[token] += amount;
        playerDeposit[msg.sender][token] += amount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount, block.timestamp);
    }

    function withdrawRequest(address token, uint256 amount) external nonReentrant {
        if (!(supportedTokens[token].isSupported && supportedTokens[token].withdrawable)) revert TokenNotSupported();
        if (amount == 0) revert AmountZero();

        if (
            !(
                withdraws[playerWithdrawRequest[msg.sender]].isConfirmed
                    || withdraws[playerWithdrawRequest[msg.sender]].isCanceled || playerWithdrawRequest[msg.sender] == 0
            )
        ) {
            revert("Last withdraw request is not confirmed or canceled");
        }

        withdrawCount++;
        withdraws[withdrawCount] = Withdraw({
            user: msg.sender,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            isConfirmed: false,
            isCanceled: false
        });
        playerWithdrawRequest[msg.sender] = withdrawCount;

        emit WithdrawRequest(msg.sender, token, amount, block.timestamp, withdrawCount);
    }

    function withdrawConfirm(uint256 withdrawId, address user, address token, uint256 amount, bytes memory signature)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        require(!withdraws[withdrawId].isConfirmed, "Withdraw request is confirmed");
        require(!withdraws[withdrawId].isCanceled, "Withdraw request is canceled");
        require(withdraws[withdrawId].user == user, "You are not the user of this withdraw request");
        require(withdraws[withdrawId].token == token, "Token mismatch");
        require(withdraws[withdrawId].amount == amount, "Amount mismatch");

        oracleNonce++;
        bytes32 message = keccak256(abi.encodePacked(block.chainid, user, token, amount, withdrawId, oracleNonce));
        _verifySignature(message, signature);

        IERC20(token).safeTransfer(user, amount);

        playerWithdraw[user][token] += amount;
        totalWithdraw[token] += amount;
        withdraws[withdrawId].isConfirmed = true;

        emit WithdrawConfirm(msg.sender, user, token, amount, block.timestamp, withdrawId);
    }

    function withdrawCancel(uint256 withdrawId, address user, bytes memory signature)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        require(!withdraws[withdrawId].isConfirmed, "Withdraw request is confirmed");
        require(!withdraws[withdrawId].isCanceled, "Withdraw request is canceled");
        require(withdraws[withdrawId].user == user, "You are not the user of this withdraw request");

        oracleNonce++;

        bytes32 message = keccak256(abi.encodePacked(block.chainid, user, withdrawId, oracleNonce));
        _verifySignature(message, signature);
        withdraws[withdrawId].isCanceled = true;

        emit WithdrawCancel(
            msg.sender, user, withdraws[withdrawId].token, withdraws[withdrawId].amount, block.timestamp, withdrawId
        );
    }

    function setPancakeRouter(address _pancakeRouter) external onlyOwner {
        address oldRouter = address(pancakeRouter);
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        emit PancakeRouterUpdated(msg.sender, oldRouter, _pancakeRouter, block.timestamp);
    }

    function addPancakeSwapInfos(address token, address pairedToken) external onlyOwner {
        pancakeSwapInfos[token] =
            PancakeSwapInfo({isSupported: true, pairedToken: pairedToken, buyFeePercent: 0, buySupported: false});

        emit PancakeSwapInfoAdded(msg.sender, token, pairedToken, block.timestamp);
    }

    function addToken(address token, uint256 minDeposit) external onlyOwner {
        require(!supportedTokens[token].isSupported, "Token already supported");

        supportedTokens[token] = TokenInfo({isSupported: true, minDeposit: minDeposit, withdrawable: true});
        tokenList.push(token);

        emit TokenAdded(msg.sender, token, minDeposit, block.timestamp);
    }

    function removeToken(address token) external onlyOwner {
        require(supportedTokens[token].isSupported, "Token not supported");

        supportedTokens[token].isSupported = false;

        // Remove from tokenList
        for (uint256 i = 0; i < tokenList.length; i++) {
            if (tokenList[i] == token) {
                tokenList[i] = tokenList[tokenList.length - 1];
                tokenList.pop();
                break;
            }
        }

        emit TokenRemoved(msg.sender, token, block.timestamp);
    }

    function setWithdrawable(address token, bool _withdrawable) external onlyOwner {
        require(supportedTokens[token].isSupported, "Token not supported");
        supportedTokens[token].withdrawable = _withdrawable;
        emit TokenWithdrawableUpdated(msg.sender, token, _withdrawable, block.timestamp);
    }

    function setBuyFee(address token, bool _buySupported, uint256 _buyFeePercent) external onlyOwner {
        require(pancakeSwapInfos[token].isSupported, "Token not supported");
        pancakeSwapInfos[token].buySupported = _buySupported;
        pancakeSwapInfos[token].buyFeePercent = _buyFeePercent;
        emit BuyFeeUpdated(msg.sender, token, _buySupported, _buyFeePercent, block.timestamp);
    }

    function setMinDeposit(address token, uint256 _minDeposit) external onlyOwner {
        require(supportedTokens[token].isSupported, "Token not supported");
        uint256 oldMinDeposit = supportedTokens[token].minDeposit;
        supportedTokens[token].minDeposit = _minDeposit;
        emit MinDepositUpdated(msg.sender, token, oldMinDeposit, _minDeposit, block.timestamp);
    }

    function setDistributeAddress(address _distributeAddress) external onlyOwner {
        address oldAddress = distributeAddress;
        distributeAddress = _distributeAddress;
        emit DistributeAddressUpdated(msg.sender, oldAddress, _distributeAddress, block.timestamp);
    }

    function setOracle(address _oracle) external onlyOwner {
        address oldOracle = oracle;
        oracle = _oracle;
        emit OracleUpdated(msg.sender, oldOracle, _oracle, block.timestamp);
    }

    function setAgt(address _agt) external onlyOwner {
        IAGT oldAgt = agt;
        agt = IAGT(_agt);
        emit AgtUpdated(msg.sender, address(oldAgt), address(agt), block.timestamp);
    }

    function setFeeWallet(address _feeWallet) external onlyOwner {
        address oldWallet = feeWallet;
        feeWallet = _feeWallet;
        emit FeeWalletUpdated(msg.sender, oldWallet, _feeWallet, block.timestamp);
    }

    function setFeePercent(uint256 _feePercent) external onlyOwner {
        require(_feePercent <= BPS, "Fee percent must be less than or equal to BPS");
        uint256 oldFeePercent = feePercent;
        feePercent = _feePercent;
        emit FeePercentUpdated(msg.sender, oldFeePercent, _feePercent, block.timestamp);
    }

    function revokeOperatorRole(address account) external onlyOwner {
        revokeRole(OPERATOR_ROLE, account);
        emit OperatorRoleRevoked(msg.sender, account, block.timestamp);
    }

    function grantOperatorRole(address account) external onlyOwner {
        grantRole(OPERATOR_ROLE, account);
        emit OperatorRoleGranted(msg.sender, account, block.timestamp);
    }

    function adminWithdraw(address token, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= getBalance(token), "Insufficient balance");

        IERC20(token).safeTransfer(msg.sender, amount);

        emit AdminWithdraw(msg.sender, token, amount, block.timestamp);
    }

    function hasOperatorRole(address account) public view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    function getBalance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getSupportedTokens() external view returns (address[] memory) {
        return tokenList;
    }

    function buyToken(
        address token,
        uint256 amount,
        uint256 deadline,
        string memory signContext,
        bytes memory signature
    ) external payable nonReentrant fundBNB {
        if (!pancakeSwapInfos[token].isSupported) revert TokenNotSupported();
        if (amount == 0) revert AmountZero();
        if (pancakeSwapInfos[token].buyFeePercent == 0) revert BuyFeeNotSet();
        if (deadline < block.timestamp) revert SignatureExpired();
        if (usedSignContexts[signContext]) revert SignContextUsed();

        bytes32 message = keccak256(abi.encodePacked(block.chainid, msg.sender, token, amount, signContext, deadline));
        _verifySignature(message, signature);
        usedSignContexts[signContext] = true;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        address pairedToken = pancakeSwapInfos[token].pairedToken;
        if (pairedToken == address(0)) revert PairedTokenNotSet();

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = pairedToken;

        // handle USDT 10% fee and transfer to fee wallet
        uint256 buy_fee = (amount * pancakeSwapInfos[token].buyFeePercent) / BPS;
        uint256 realAmount = amount - buy_fee;
        IERC20(token).safeTransfer(feeWallet, buy_fee);

        _approveExact(token, realAmount);
        uint256 amountOut = _swapSupportingFeeReturnOut(realAmount, path, deadline);

        emit TokenBought(msg.sender, token, amount, pairedToken, amountOut, signContext, signature);
        treasuryHedge.execute(amountOut, true);
    }

    function mintPairedToken(
        address token,
        uint256 amount,
        uint256 deadline,
        string memory signContext,
        bytes memory signature
    ) external payable nonReentrant fundBNB returns (uint256) {
        if (!pancakeSwapInfos[token].isSupported) revert TokenNotSupported();

        if (amount == 0) revert AmountZero();
        require(amount <= getBalance(token), "Insufficient balance");
        if (deadline < block.timestamp) revert SignatureExpired();

        if (usedSignContexts[signContext]) revert SignContextUsed();

        bytes32 message = keccak256(abi.encodePacked(block.chainid, msg.sender, token, amount, signContext, deadline));
        _verifySignature(message, signature);
        usedSignContexts[signContext] = true;
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(agt);

        _approveExact(token, amount);
        uint256 amountOut = _swapSupportingFeeReturnOut(amount, path, deadline);
        emit PairedTokenMinted(msg.sender, token, amount, address(agt), amountOut, signContext, signature);
        return amountOut;
    }

    function mintWonToken(
        address token,
        uint256 amount,
        uint256 deadline,
        string memory signContext,
        bytes memory signature
    ) external payable nonReentrant fundBNB returns (uint256) {
        if (!pancakeSwapInfos[token].isSupported) revert TokenNotSupported();
        require(token == address(fusd), "Not allow other token call");
        if (amount == 0) revert AmountZero();
        require(amount <= getBalance(token), "Insufficient balance");
        if (deadline < block.timestamp) revert SignatureExpired();

        if (usedSignContexts[signContext]) revert SignContextUsed();

        bytes32 message = keccak256(abi.encodePacked(block.chainid, msg.sender, token, amount, signContext, deadline));
        _verifySignature(message, signature);
        usedSignContexts[signContext] = true;

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(agt);

        _approveExact(token, amount);
        uint256 amountOut = _swapSupportingFeeReturnOut(amount, path, deadline);
        if (amountOut <= hold_fee) revert InsufficientPairedOutput();
        // transfer some token to msg sender for holding count
        IERC20(address(agt)).safeTransfer(_msgSender(), hold_fee);

        emit PairedTokenRewardsClaimed(
            msg.sender, token, 0, address(agt), amountOut - hold_fee, claimFeePercent, signContext, signature
        );

        return amountOut - hold_fee;
    }

    function claimPairedTokenRewards(
        address token,
        uint256 amount,
        uint256 deadline,
        string memory signContext,
        bytes memory signature
    ) external payable nonReentrant fundBNB returns (uint256[] memory amounts) {
        if (!pancakeSwapInfos[token].isSupported) revert TokenNotSupported();

        if (amount == 0) revert AmountZero();
        require(amount <= getBalance(token), "Insufficient balance");
        if (deadline < block.timestamp) revert SignatureExpired();
        if (usedSignContexts[signContext]) revert SignContextUsed();

        bytes32 message = keccak256(abi.encodePacked(block.chainid, msg.sender, token, amount, signContext, deadline));
        _verifySignature(message, signature);
        usedSignContexts[signContext] = true;

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(agt);

        uint256 sell_amount = (amount * claimFeePercent) / BPS;
        _approveExact(token, amount);
        uint256 amountPairedOut = _swapSupportingFeeReturnOut(sell_amount, path, deadline);

        emit PairedTokenRewardsClaimed(
            msg.sender,
            token,
            amount - sell_amount,
            address(agt),
            amountPairedOut,
            claimFeePercent,
            signContext,
            signature
        );

        uint256[] memory amountsOut = new uint256[](2);
        amountsOut[0] = amount;
        amountsOut[1] = amountPairedOut;
        return amountsOut;
    }

    function getTokenInfo(address token) external view returns (bool isSupported, uint256 minDeposit) {
        TokenInfo memory info = supportedTokens[token];
        return (info.isSupported, info.minDeposit);
    }

    function setMerkleRoot(bytes32 newMerkleRoot, bytes memory signature)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        oracleNonce++;
        bytes32 message = keccak256(abi.encodePacked(block.chainid, newMerkleRoot, oracleNonce));
        _verifySignature(message, signature);

        bytes32 oldRoot = merkleRoot;
        merkleRoot = newMerkleRoot;

        emit MerkleRootUpdated(msg.sender, oldRoot, newMerkleRoot, block.timestamp);
    }

    function verifyMerkleProof(bytes32[] memory proof, bytes32 leaf) public view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == merkleRoot;
    }

    function swapTokensForTokens(address tokenIn, address tokenOut, uint256 amountIn, address to, uint256 deadline)
        external
        payable
        nonReentrant
        fundBNB
    {
        if (amountIn == 0) revert AmountZero();
        if (deadline <= block.timestamp) revert SignatureExpired();
        // Transfer tokens from user to contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve the router to spend the tokens
        _approveExact(tokenIn, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // 限制买, 只能卖
        if (
            !(
                (path[0] == address(fusd) && path[1] == address(usdt))
                    || (path[0] == address(agt) && path[1] == address(fusd))
            )
        ) revert OnlySellPathsAllowed();

        uint256 amountOut = _swapSupportingFeeReturnOut(amountIn, path, deadline);
        IERC20(tokenOut).safeTransfer(to, amountOut);

        if (path[0] == address(usdt) || path[1] == address(usdt)) {
            // handle USDT <-> FUSD
            if (path[0] == address(usdt)) {
                treasuryHedge.execute(amountOut, true);
            } else {
                treasuryHedge.execute(amountOut, false);
            }
        }

        //emit Event
        emit Swap(msg.sender, path[0], path[1], amountIn, amountOut);
    }

    function validToken(address token) public view returns (bool) {
        return supportedTokens[token].isSupported;
    }

    function validTokenPair(address tokenA, address tokenB) public view returns (bool) {
        bool t = validToken(tokenA);
        address pairedToken = pancakeSwapInfos[tokenA].pairedToken;
        return (t && pairedToken == tokenB);
    }

    function getAmountsOut(address tokenIn, address tokenOut, uint256 amountIn) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256 estAmountOut = pancakeRouter.getAmountsOut(amountIn, path)[1];

        return estAmountOut;
    }

    function setClaimFeePercent(uint256 _claimFeePercent) external onlyOwner {
        require(_claimFeePercent <= BPS, "Claim fee percent must be less than or equal to BPS");
        uint256 oldClaimFeePercent = claimFeePercent;
        claimFeePercent = _claimFeePercent;
        emit ClaimFeePercentUpdated(msg.sender, oldClaimFeePercent, _claimFeePercent, block.timestamp);
    }

    function setSlippageBps(uint256 _slippageBps) external onlyOwner {
        require(_slippageBps <= 2000, "slippage too high");
        slippageBps = _slippageBps;
    }

    function setUsdt(address _usdt) external onlyOwner {
        address oldUsdt = usdt;
        usdt = _usdt;
        emit UsdtUpdated(msg.sender, oldUsdt, _usdt, block.timestamp);
    }

    function setLpToken(address _lpToken) external onlyOwner {
        address oldLpToken = lp_token;
        lp_token = _lpToken;
        emit LpTokenUpdated(msg.sender, oldLpToken, _lpToken, block.timestamp);
    }

    function setBnbFee(uint256 _bnbFee) external onlyOwner {
        uint256 oldFee = bnb_fee;
        bnb_fee = _bnbFee;
        emit BnbFeeUpdated(msg.sender, oldFee, _bnbFee, block.timestamp);
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success,) = msg.sender.call{value: amount}("");
            require(success, "BNB withdrawal failed");
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
        emit EmergencyWithdrawal(msg.sender, token, amount, block.timestamp);
    }

    // 提取签名验证逻辑
    function _verifySignature(bytes32 message, bytes memory signature) internal view {
        require(signature.length == 65, "bad sig length");
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(message);
        (address recovered,,) = ECDSA.tryRecover(ethSignedMessageHash, signature);
        require(oracle == recovered, "Invalid oracle signature");
    }

    function _approveExact(address token, uint256 amount) internal {
        IERC20(token).approve(address(pancakeRouter), 0);
        IERC20(token).approve(address(pancakeRouter), amount);
    }

    function _swapSupportingFeeReturnOut(uint256 amountIn, address[] memory path, uint256 deadline)
        internal
        returns (uint256 amountOut)
    {
        uint256 balanceBefore = IERC20(path[1]).balanceOf(address(this));
        uint256 expectedOut = pancakeRouter.getAmountsOut(amountIn, path)[1];
        uint256 minOut = (expectedOut * (BPS - slippageBps)) / BPS;
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, minOut, path, address(this), deadline
        );
        uint256 balanceAfter = IERC20(path[1]).balanceOf(address(this));
        amountOut = balanceAfter - balanceBefore;
    }

    receive() external payable {}

    function claimNodeCardRewards(
        address tokenA,
        uint256 amount,
        address tokenB,
        uint256 amountB,
        uint256 deadline,
        string memory signContext,
        bytes memory signature
    ) external payable nonReentrant fundBNB {
        require(deadline >= block.timestamp, "Signature expired");
        require(!usedSignContexts[signContext], "Sign context already used");

        bytes32 message = keccak256(
            abi.encodePacked(block.chainid, msg.sender, tokenA, amount, tokenB, amountB, signContext, deadline)
        );

        _verifySignature(message, signature);
        usedSignContexts[signContext] = true;

        if (amount > 0) {
            //A => B
            address[] memory path = new address[](2);
            path[0] = tokenA;
            path[1] = tokenB;

            _approveExact(tokenA, amount);
            uint256 sell_amount = (amount * claimFeePercent) / BPS;
            uint256 amountPairedOut = _swapSupportingFeeReturnOut(sell_amount, path, deadline);

            emit PairedTokenARewardsClaimed(
                msg.sender,
                tokenA,
                amount - sell_amount,
                tokenB,
                amountPairedOut,
                claimFeePercent,
                signContext,
                signature
            );
        }

        if (amountB > 0) {
            //B => A
            address[] memory path = new address[](2);
            path[0] = tokenB;
            path[1] = tokenA;
            _approveExact(tokenB, amountB);
            uint256 sell_amount = (amountB * claimFeePercent) / BPS;
            uint256 amountPairedOut = _swapSupportingFeeReturnOut(sell_amount, path, deadline);
            emit PairedTokenBRewardsClaimed(
                msg.sender,
                tokenB,
                amountB - sell_amount,
                tokenA,
                amountPairedOut,
                claimFeePercent,
                signContext,
                signature
            );
        }
    }

    function dailyBurnToken(address token, uint256 amount, bytes memory signature)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        require(supportedTokens[token].isSupported, "Token not supported");

        oracleNonce++;
        bytes32 message = keccak256(abi.encodePacked(block.chainid, address(this), token, amount, oracleNonce));
        _verifySignature(message, signature);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = address(agt);

        _approveExact(token, amount);
        uint256 amountPairedOut = _swapSupportingFeeReturnOut(amount, path, block.timestamp);

        agt.burn(amountPairedOut);

        emit DailyTokenBurn(
            msg.sender, token, amount, address(agt), amountPairedOut, block.timestamp, oracleNonce, signature
        );
    }
}

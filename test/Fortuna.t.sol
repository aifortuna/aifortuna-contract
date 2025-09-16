// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Fortuna.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/AGT.sol";
import "../src/FUSD.sol";
import "../src/Treasury.sol";
import "../src/mock/MockERC20.sol";
import "../src/interfaces/IPancakeRouter02.sol";

contract MockPancakeRouter is IPancakeRouter02 {
    function factory() external pure override returns (address) {
        return address(0);
    }

    function WETH() external pure override returns (address) {
        return address(0);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        return (0, 0, 0);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable override returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        return (0, 0, 0);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountA, uint256 amountB) {
        return (0, 0);
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        return (0, 0);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountA, uint256 amountB) {
        return (0, 0);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountToken, uint256 amountETH) {
        return (0, 0);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = (amountIn * 98) / 100; // 2% slippage
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).transfer(to, amounts[1]);
        return amounts;
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = (amountOut * 102) / 100; // 2% slippage
        amounts[1] = amountOut;
        IERC20(path[0]).transferFrom(msg.sender, address(this), amounts[0]);
        IERC20(path[1]).transfer(to, amounts[1]);
        return amounts;
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = msg.value;
        amounts[1] = (msg.value * 98) / 100;
        return amounts;
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = (amountOut * 102) / 100;
        amounts[1] = amountOut;
        return amounts;
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = (amountIn * 98) / 100;
        return amounts;
    }

    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = (amountOut * 102) / 100;
        amounts[1] = amountOut;
        return amounts;
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        external
        pure
        override
        returns (uint256 amountB)
    {
        return (amountA * reserveB) / reserveA;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return (amountIn * reserveOut) / (reserveIn + amountIn);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        override
        returns (uint256 amountIn)
    {
        return (reserveIn * amountOut) / (reserveOut - amountOut);
    }

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        pure
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i = 1; i < path.length; i++) {
            amounts[i] = (amounts[i - 1] * 98) / 100; // 2% slippage per hop
        }
        return amounts;
    }

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        pure
        override
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](path.length);
        amounts[path.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            amounts[i - 1] = (amounts[i] * 102) / 100; // 2% slippage per hop
        }
        return amounts;
    }

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountETH) {
        return 0;
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountETH) {
        return 0;
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override {
        uint256 amountOut = (amountIn * 98) / 100; // 2% slippage
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[1]).transfer(to, amountOut);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable override {}

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external override {}
}

contract MockTreasuryHedge {
    function execute(uint256 amount, bool isBuy) external {}
}

contract FortunaTest is Test {
    Fortuna public fortuna;
    AGT public agt;
    FUSD public fusd;
    Treasury public treasury;
    MockERC20 public usdt;
    MockERC20 public gameToken1;
    MockERC20 public gameToken2;
    MockPancakeRouter public pancakeRouter;
    MockTreasuryHedge public treasuryHedge;

    address public owner;
    address public oracle;
    address public operator;
    address public feeWallet;
    address public distributeAddress;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;
    uint256 public constant MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 public constant FEE_PERCENT = 300; // 3%
    uint256 public constant BPS = 10000;
    uint256 public constant BNB_FEE = 0.0002 ether; // BNB fee for operations

    uint256 oraclePrivateKey;
    uint256 userPrivateKey;

    // Events
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
    event TokenAdded(address indexed operator, address indexed token, uint256 minDeposit, uint256 timestamp);
    event AdminWithdraw(address indexed operator, address indexed token, uint256 amount, uint256 timestamp);

    function setUp() public {
        owner = address(this);
        oracle = makeAddr("oracle");
        operator = makeAddr("operator");
        feeWallet = makeAddr("feeWallet");
        distributeAddress = makeAddr("distributeAddress");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        oraclePrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        oracle = vm.addr(oraclePrivateKey);

        userPrivateKey = 0x1111111111111111111111111111111111111111111111111111111111111111;
        user1 = vm.addr(userPrivateKey);

        // Deploy mock tokens
        usdt = new MockERC20("USDT", "USDT", 18);
        gameToken1 = new MockERC20("GameToken1", "GT1", 18);
        gameToken2 = new MockERC20("GameToken2", "GT2", 18);

        // Deploy AGT and FUSD
        agt = new AGT(INITIAL_SUPPLY, user1);
        agt.setFeeWallet(feeWallet);
        agt.setGameContract(distributeAddress);
        treasury = new Treasury();
        // Initialize minimal treasury to avoid interactions during tests
        // FUSD uses only addresses for team and gameContract in these tests
        fusd = new FUSD(address(treasury), INITIAL_SUPPLY, address(treasury));

        // Deploy mock contracts
        pancakeRouter = new MockPancakeRouter();
        treasuryHedge = new MockTreasuryHedge();

        // Setup token lists
        address[] memory gameTokens = new address[](2);
        gameTokens[0] = address(gameToken1);
        gameTokens[1] = address(gameToken2);

        uint256[] memory minDeposits = new uint256[](2);
        minDeposits[0] = MIN_DEPOSIT;
        minDeposits[1] = MIN_DEPOSIT;

        // Deploy Fortuna implementation and initialize via ERC1967 proxy
        Fortuna impl = new Fortuna();
        bytes memory initData = abi.encodeWithSelector(
            Fortuna.initialize.selector,
            gameTokens,
            minDeposits,
            oracle,
            feeWallet,
            FEE_PERCENT,
            distributeAddress,
            address(pancakeRouter),
            address(usdt),
            address(treasuryHedge),
            address(fusd),
            address(agt),
            5000 // claimFeePercent 50%
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        fortuna = Fortuna(payable(address(proxy)));
        fortuna.setBnbFee(BNB_FEE);

        // Grant operator role
        fortuna.grantOperatorRole(operator);

        // Mint tokens to users
        gameToken1.mint(user1, INITIAL_SUPPLY);
        gameToken2.mint(user1, INITIAL_SUPPLY);
        usdt.mint(user1, INITIAL_SUPPLY);
        gameToken1.mint(user2, INITIAL_SUPPLY);
        gameToken2.mint(user2, INITIAL_SUPPLY);
        // Provide AGT to user1 for AGT -> FUSD swap path
        agt.transfer(user1, INITIAL_SUPPLY);

        // Prepare FUSD balances and permissions for swap tests
        fusd.setMinter(address(this), true);
        fusd.mint(user1, INITIAL_SUPPLY);
        fusd.mint(address(pancakeRouter), INITIAL_SUPPLY);

        // Mint tokens to router for swaps
        agt.transfer(address(pancakeRouter), INITIAL_SUPPLY / 2);
        gameToken1.mint(address(pancakeRouter), INITIAL_SUPPLY);
        gameToken2.mint(address(pancakeRouter), INITIAL_SUPPLY);
        usdt.mint(address(pancakeRouter), INITIAL_SUPPLY);

        // Setup approvals
        vm.prank(user1);
        gameToken1.approve(address(fortuna), INITIAL_SUPPLY);
        vm.prank(user1);
        gameToken2.approve(address(fortuna), INITIAL_SUPPLY);
        vm.prank(user1);
        usdt.approve(address(fortuna), INITIAL_SUPPLY);

        vm.prank(user2);
        gameToken1.approve(address(fortuna), INITIAL_SUPPLY);
        vm.prank(user2);
        gameToken2.approve(address(fortuna), INITIAL_SUPPLY);

        // Approvals for allowed swap pairs
        vm.prank(user1);
        agt.approve(address(fortuna), type(uint256).max);
        vm.prank(user1);
        fusd.approve(address(fortuna), type(uint256).max);
    }

    // ============ Initialization Tests ============
    function testInitialization() public view {
        assertEq(fortuna.owner(), owner);
        assertEq(fortuna.oracle(), oracle);
        assertEq(fortuna.feeWallet(), feeWallet);
        assertEq(fortuna.feePercent(), FEE_PERCENT);
        assertEq(fortuna.distributeAddress(), distributeAddress);
        assertEq(fortuna.withdrawCount(), 1);
        assertTrue(fortuna.hasOperatorRole(operator));

        (bool isSupported, uint256 minDeposit) = fortuna.getTokenInfo(address(gameToken1));
        assertTrue(isSupported);
        assertEq(minDeposit, MIN_DEPOSIT);
    }

    // ============ Deposit Tests ============
    function testDeposit() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;
        uint256 balanceBefore = gameToken1.balanceOf(user1);

        vm.expectEmit(true, true, false, true);
        emit Deposit(user1, address(gameToken1), depositAmount, block.timestamp);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        assertEq(gameToken1.balanceOf(user1), balanceBefore - depositAmount);
        assertEq(gameToken1.balanceOf(address(fortuna)), depositAmount);
        assertEq(fortuna.totalDeposit(address(gameToken1)), depositAmount);
        assertEq(fortuna.playerDeposit(user1, address(gameToken1)), depositAmount);
    }

    function testDepositUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);
        unsupportedToken.mint(user1, 1000 * 10 ** 18);

        vm.prank(user1);
        unsupportedToken.approve(address(fortuna), 1000 * 10 ** 18);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(TokenNotSupported.selector);
        fortuna.deposit(address(unsupportedToken), 100 * 10 ** 18);
    }

    function testDepositBelowMinimum() public {
        uint256 belowMinAmount = MIN_DEPOSIT - 1;

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than minDeposit");
        fortuna.deposit(address(gameToken1), belowMinAmount);
    }

    // ============ Withdraw Request Tests ============
    function testWithdrawRequest() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for both deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.expectEmit(true, true, false, true);
        emit WithdrawRequest(user1, address(gameToken1), depositAmount, block.timestamp, 2);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        assertEq(fortuna.playerWithdrawRequest(user1), 2);

        (address user, address token, uint256 amount, uint256 timestamp, bool isConfirmed, bool isCanceled) =
            fortuna.withdraws(2);

        assertEq(user, user1);
        assertEq(token, address(gameToken1));
        assertEq(amount, depositAmount);
        assertEq(timestamp, block.timestamp);
        assertFalse(isConfirmed);
        assertFalse(isCanceled);
    }

    function testWithdrawRequestPendingRequest() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 3); // Need BNB for deposit and 2 withdrawRequest calls
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        // Try to make another request while first is pending
        vm.prank(user1);
        vm.expectRevert("Last withdraw request is not confirmed or canceled");
        fortuna.withdrawRequest(address(gameToken1), depositAmount);
    }

    function testWithdrawRequestZeroAmount() public {
        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(AmountZero.selector);
        fortuna.withdrawRequest(address(gameToken1), 0);
    }

    // ============ Signature Helper Functions ============
    function signWithdrawConfirm(address user, address token, uint256 amount, uint256 withdrawId, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        bytes32 message = keccak256(abi.encodePacked(block.chainid, user, token, amount, withdrawId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function signWithdrawCancel(address user, uint256 withdrawId, uint256 nonce) internal view returns (bytes memory) {
        bytes32 message = keccak256(abi.encodePacked(block.chainid, user, withdrawId, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // ============ Withdraw Confirm Tests ============
    function testWithdrawConfirm() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        // Deposit and request withdraw
        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        uint256 withdrawId = 2;
        uint256 nonce = fortuna.oracleNonce() + 1;
        bytes memory signature = signWithdrawConfirm(user1, address(gameToken1), depositAmount, withdrawId, nonce);

        uint256 expectedFee = (depositAmount * FEE_PERCENT) / BPS;
        uint256 expectedAmount = depositAmount - expectedFee;

        uint256 userBalanceBefore = gameToken1.balanceOf(user1);
        uint256 feeWalletBalanceBefore = gameToken1.balanceOf(feeWallet);

        vm.expectEmit(true, true, true, true);
        emit WithdrawConfirm(operator, user1, address(gameToken1), depositAmount, block.timestamp, withdrawId);

        vm.prank(operator);
        fortuna.withdrawConfirm(withdrawId, user1, address(gameToken1), depositAmount, signature);

        assertEq(gameToken1.balanceOf(user1), userBalanceBefore + expectedAmount);
        assertEq(gameToken1.balanceOf(feeWallet), feeWalletBalanceBefore + expectedFee);
        assertEq(fortuna.playerWithdraw(user1, address(gameToken1)), expectedAmount);
        assertEq(fortuna.totalWithdraw(address(gameToken1)), expectedAmount);
        assertEq(fortuna.totalFee(address(gameToken1)), expectedFee);

        (,,,, bool isConfirmed,) = fortuna.withdraws(withdrawId);
        assertTrue(isConfirmed);
    }

    function testWithdrawConfirmInvalidSignature() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        uint256 withdrawId = 2;
        bytes memory invalidSignature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        vm.prank(operator);
        vm.expectRevert("Invalid oracle signature");
        fortuna.withdrawConfirm(withdrawId, user1, address(gameToken1), depositAmount, invalidSignature);
    }

    function testWithdrawConfirmAlreadyConfirmed() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        uint256 withdrawId = 2;
        uint256 nonce = fortuna.oracleNonce() + 1;
        bytes memory signature = signWithdrawConfirm(user1, address(gameToken1), depositAmount, withdrawId, nonce);

        vm.prank(operator);
        fortuna.withdrawConfirm(withdrawId, user1, address(gameToken1), depositAmount, signature);

        // Try to confirm again
        nonce = fortuna.oracleNonce() + 1;
        signature = signWithdrawConfirm(user1, address(gameToken1), depositAmount, withdrawId, nonce);

        vm.prank(operator);
        vm.expectRevert("Withdraw request is confirmed");
        fortuna.withdrawConfirm(withdrawId, user1, address(gameToken1), depositAmount, signature);
    }

    // ============ Withdraw Cancel Tests ============
    function testWithdrawCancel() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        uint256 withdrawId = 2;
        uint256 nonce = fortuna.oracleNonce() + 1;
        bytes memory signature = signWithdrawCancel(user1, withdrawId, nonce);

        vm.expectEmit(true, true, true, true);
        emit WithdrawCancel(operator, user1, address(gameToken1), depositAmount, block.timestamp, withdrawId);

        vm.prank(operator);
        fortuna.withdrawCancel(withdrawId, user1, signature);

        (,,,,, bool isCanceled) = fortuna.withdraws(withdrawId);
        assertTrue(isCanceled);
    }

    // ============ Token Management Tests ============
    function testAddToken() public {
        MockERC20 newToken = new MockERC20("NewToken", "NT", 18);
        uint256 minDeposit = 50 * 10 ** 18;

        vm.expectEmit(true, true, false, true);
        emit TokenAdded(owner, address(newToken), minDeposit, block.timestamp);

        fortuna.addToken(address(newToken), minDeposit);

        (bool isSupported, uint256 storedMinDeposit) = fortuna.getTokenInfo(address(newToken));
        assertTrue(isSupported);
        assertEq(storedMinDeposit, minDeposit);
    }

    function testAddExistingToken() public {
        vm.expectRevert("Token already supported");
        fortuna.addToken(address(gameToken1), MIN_DEPOSIT);
    }

    function testRemoveToken() public {
        fortuna.removeToken(address(gameToken1));

        (bool isSupported,) = fortuna.getTokenInfo(address(gameToken1));
        assertFalse(isSupported);
    }

    function testRemoveNonExistentToken() public {
        MockERC20 nonExistentToken = new MockERC20("NonExistent", "NE", 18);

        vm.expectRevert("Token not supported");
        fortuna.removeToken(address(nonExistentToken));
    }

    // ============ Access Control Tests ============
    function testOnlyOwnerFunctions() public {
        vm.prank(user1);
        vm.expectRevert();
        fortuna.addToken(address(gameToken1), MIN_DEPOSIT);

        vm.prank(user1);
        vm.expectRevert();
        fortuna.setFeePercent(500);

        vm.prank(user1);
        vm.expectRevert();
        fortuna.setOracle(user2);
    }

    function testOnlyOperatorFunctions() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and withdrawRequest
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), depositAmount);

        uint256 withdrawId = 2;
        uint256 nonce = fortuna.oracleNonce() + 1;
        bytes memory signature = signWithdrawConfirm(user1, address(gameToken1), depositAmount, withdrawId, nonce);

        vm.prank(user1);
        vm.expectRevert();
        fortuna.withdrawConfirm(withdrawId, user1, address(gameToken1), depositAmount, signature);
    }

    // ============ Admin Functions Tests ============
    function testAdminWithdraw() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        uint256 withdrawAmount = depositAmount / 2;
        uint256 ownerBalanceBefore = gameToken1.balanceOf(owner);

        vm.expectEmit(true, true, false, true);
        emit AdminWithdraw(owner, address(gameToken1), withdrawAmount, block.timestamp);

        fortuna.adminWithdraw(address(gameToken1), withdrawAmount);

        assertEq(gameToken1.balanceOf(owner), ownerBalanceBefore + withdrawAmount);
        assertEq(gameToken1.balanceOf(address(fortuna)), depositAmount - withdrawAmount);
    }

    function testAdminWithdrawInsufficientBalance() public {
        uint256 excessiveAmount = INITIAL_SUPPLY;

        vm.expectRevert("Insufficient balance");
        fortuna.adminWithdraw(address(gameToken1), excessiveAmount);
    }

    // ============ Pancake Swap Tests ============
    function testAddPancakeSwapInfos() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        (bool isSupported, address pairedToken, uint256 buyFeePercent, bool buySupported) =
            fortuna.pancakeSwapInfos(address(gameToken1));

        assertTrue(isSupported);
        assertEq(pairedToken, address(agt));
        assertEq(buyFeePercent, 0);
        assertFalse(buySupported);
    }

    // ============ Configuration Tests ============
    function testSetFeePercent() public {
        uint256 newFeePercent = 500; // 5%

        fortuna.setFeePercent(newFeePercent);
        assertEq(fortuna.feePercent(), newFeePercent);
    }

    function testSetFeePercentTooHigh() public {
        vm.expectRevert("Fee percent must be less than or equal to BPS");
        fortuna.setFeePercent(BPS + 1);
    }

    function testSetOracle() public {
        address newOracle = makeAddr("newOracle");

        fortuna.setOracle(newOracle);
        assertEq(fortuna.oracle(), newOracle);
    }

    function testSetFeeWallet() public {
        address newFeeWallet = makeAddr("newFeeWallet");

        fortuna.setFeeWallet(newFeeWallet);
        assertEq(fortuna.feeWallet(), newFeeWallet);
    }

    function testSetDistributeAddress() public {
        address newDistributeAddress = makeAddr("newDistributeAddress");

        fortuna.setDistributeAddress(newDistributeAddress);
        assertEq(fortuna.distributeAddress(), newDistributeAddress);
    }

    // ============ View Functions Tests ============
    function testGetBalance() public {
        uint256 depositAmount = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        assertEq(fortuna.getBalance(address(gameToken1)), depositAmount);
    }

    function testGetSupportedTokens() public view {
        address[] memory supportedTokens = fortuna.getSupportedTokens();
        assertEq(supportedTokens.length, 2);
        assertEq(supportedTokens[0], address(gameToken1));
        assertEq(supportedTokens[1], address(gameToken2));
    }

    function testHasOperatorRole() public view {
        assertTrue(fortuna.hasOperatorRole(operator));
        assertFalse(fortuna.hasOperatorRole(user1));
    }

    // ============ Edge Cases Tests ============
    function testMultipleDeposits() public {
        uint256 deposit1 = MIN_DEPOSIT;
        uint256 deposit2 = MIN_DEPOSIT * 2;

        vm.deal(user1, BNB_FEE * 2); // Need BNB for both deposits
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), deposit1);

        vm.prank(user1);
        fortuna.deposit(address(gameToken1), deposit2);

        assertEq(fortuna.playerDeposit(user1, address(gameToken1)), deposit1 + deposit2);
        assertEq(fortuna.totalDeposit(address(gameToken1)), deposit1 + deposit2);
    }

    function testForceSetWithdrawCount() public {
        uint256 newCount = 100;

        fortuna.forceSetWithdrawCount(newCount);
        assertEq(fortuna.withdrawCount(), newCount);
    }

    function testOperatorRoleManagement() public {
        address newOperator = makeAddr("newOperator");

        fortuna.grantOperatorRole(newOperator);
        assertTrue(fortuna.hasOperatorRole(newOperator));

        fortuna.revokeOperatorRole(newOperator);
        assertFalse(fortuna.hasOperatorRole(newOperator));
    }

    function testSetWithdrawable() public {
        fortuna.setWithdrawable(address(gameToken1), false);

        vm.deal(user1, BNB_FEE * 3); // Need BNB for withdrawRequest and deposit and another withdrawRequest
        vm.prank(user1);
        vm.expectRevert(TokenNotSupported.selector);
        fortuna.withdrawRequest(address(gameToken1), MIN_DEPOSIT);

        fortuna.setWithdrawable(address(gameToken1), true);

        vm.prank(user1);
        fortuna.deposit(address(gameToken1), MIN_DEPOSIT);

        vm.prank(user1);
        fortuna.withdrawRequest(address(gameToken1), MIN_DEPOSIT); // Should not revert
    }

    // ============ Core Swap Functions Tests ============

    // Helper function to sign for trading functions
    function signTrading(address user, address token, uint256 amount, string memory signContext, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 message = keccak256(abi.encodePacked(block.chainid, user, token, amount, signContext, deadline));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    // ============ buyToken Tests ============
    function testBuyToken() public {
        // Setup pancake swap info for gameToken1
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));
        fortuna.setBuyFee(address(gameToken1), true, 500); // 5% fee

        uint256 buyAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_001";

        bytes memory signature = signTrading(user1, address(gameToken1), buyAmount, signContext, deadline);

        uint256 initialAgtBalance = agt.balanceOf(address(fortuna));
        uint256 userTokenBalanceBefore = gameToken1.balanceOf(user1);

        vm.expectEmit(true, true, false, false);
        emit TokenBought(user1, address(gameToken1), buyAmount, address(agt), 0, signContext, signature);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), buyAmount, deadline, signContext, signature);

        // Verify token was transferred from user
        assertEq(gameToken1.balanceOf(user1), userTokenBalanceBefore - buyAmount);

        // Verify AGT balance increased (from swap)
        assertTrue(agt.balanceOf(address(fortuna)) > initialAgtBalance);
    }

    function testBuyTokenUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);
        uint256 buyAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_002";

        bytes memory signature = signTrading(user1, address(unsupportedToken), buyAmount, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(TokenNotSupported.selector);
        fortuna.buyToken{value: BNB_FEE}(address(unsupportedToken), buyAmount, deadline, signContext, signature);
    }

    function testBuyTokenZeroAmount() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));
        fortuna.setBuyFee(address(gameToken1), true, 500);

        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_003";

        bytes memory signature = signTrading(user1, address(gameToken1), 0, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(AmountZero.selector);
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), 0, deadline, signContext, signature);
    }

    function testBuyTokenFeeNotSet() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));
        // Don't set buy fee

        uint256 buyAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_004";

        bytes memory signature = signTrading(user1, address(gameToken1), buyAmount, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(BuyFeeNotSet.selector);
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), buyAmount, deadline, signContext, signature);
    }

    function testBuyTokenInvalidSignature() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));
        fortuna.setBuyFee(address(gameToken1), true, 500);

        uint256 buyAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_005";

        bytes memory invalidSignature = abi.encodePacked(bytes32(0), bytes32(0), uint8(0));

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert("Invalid oracle signature");
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), buyAmount, deadline, signContext, invalidSignature);
    }

    function testBuyTokenReusedSignContext() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));
        fortuna.setBuyFee(address(gameToken1), true, 500);

        uint256 buyAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_buy_006";

        bytes memory signature = signTrading(user1, address(gameToken1), buyAmount, signContext, deadline);

        // First call should succeed
        vm.deal(user1, BNB_FEE * 2); // Need BNB for both calls
        vm.prank(user1);
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), buyAmount, deadline, signContext, signature);

        // Second call with same signContext should fail
        vm.prank(user1);
        vm.expectRevert(SignContextUsed.selector);
        fortuna.buyToken{value: BNB_FEE}(address(gameToken1), buyAmount, deadline, signContext, signature);
    }

    // ============ mintPairedToken Tests ============
    function testMintPairedToken() public {
        // Setup
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        // Deposit some tokens first
        uint256 depositAmount = MIN_DEPOSIT * 2;
        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and mintPairedToken
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        uint256 mintAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_mint_001";

        bytes memory signature = signTrading(user1, address(gameToken1), mintAmount, signContext, deadline);

        uint256 initialAgtBalance = agt.balanceOf(address(fortuna));

        vm.expectEmit(true, true, false, false);
        emit PairedTokenMinted(user1, address(gameToken1), mintAmount, address(agt), 0, signContext, signature);

        vm.prank(user1);
        uint256 amountOut =
            fortuna.mintPairedToken{value: BNB_FEE}(address(gameToken1), mintAmount, deadline, signContext, signature);

        // Verify AGT was received
        assertTrue(agt.balanceOf(address(fortuna)) > initialAgtBalance);
        assertTrue(amountOut > 0);
    }

    function testMintPairedTokenInsufficientBalance() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 mintAmount = MIN_DEPOSIT * 100; // More than available
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_mint_002";

        bytes memory signature = signTrading(user1, address(gameToken1), mintAmount, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        fortuna.mintPairedToken{value: BNB_FEE}(address(gameToken1), mintAmount, deadline, signContext, signature);
    }

    function testMintPairedTokenExpiredSignature() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        // Deposit some tokens first
        uint256 depositAmount = MIN_DEPOSIT * 2;
        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and mintPairedToken
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        uint256 mintAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp - 1; // Expired
        string memory signContext = "test_mint_003";

        bytes memory signature = signTrading(user1, address(gameToken1), mintAmount, signContext, deadline);

        vm.prank(user1);
        vm.expectRevert(SignatureExpired.selector);
        fortuna.mintPairedToken{value: BNB_FEE}(address(gameToken1), mintAmount, deadline, signContext, signature);
    }

    function testMintPairedTokenUnsupportedToken() public {
        MockERC20 unsupportedToken = new MockERC20("Unsupported", "UNS", 18);

        uint256 mintAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_mint_004";

        bytes memory signature = signTrading(user1, address(unsupportedToken), mintAmount, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(TokenNotSupported.selector);
        fortuna.mintPairedToken{value: BNB_FEE}(address(unsupportedToken), mintAmount, deadline, signContext, signature);
    }

    // ============ claimPairedTokenRewards Tests ============
    function testClaimPairedTokenRewards() public {
        // Setup
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        // Deposit some tokens first
        uint256 depositAmount = MIN_DEPOSIT * 2;
        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and claimPairedTokenRewards
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        uint256 claimAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_claim_001";

        bytes memory signature = signTrading(user1, address(gameToken1), claimAmount, signContext, deadline);

        uint256 initialAgtBalance = agt.balanceOf(address(fortuna));

        // 事件中的 tokenAmountOut = amount - sell_amount = 50% of claimAmount
        vm.expectEmit(true, true, true, false);
        emit PairedTokenRewardsClaimed(
            user1, address(gameToken1), claimAmount / 2, address(agt), 0, 5000, signContext, signature
        );

        vm.prank(user1);
        uint256[] memory amounts = fortuna.claimPairedTokenRewards{value: BNB_FEE}(
            address(gameToken1), claimAmount, deadline, signContext, signature
        );

        // Verify return values: function returns [amount, pairedOut]
        assertEq(amounts[0], claimAmount);
        assertTrue(amounts[1] > 0); // Some AGT was received

        // Verify AGT balance increased
        assertTrue(agt.balanceOf(address(fortuna)) > initialAgtBalance);
    }

    function testClaimPairedTokenRewardsInsufficientBalance() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 claimAmount = MIN_DEPOSIT * 100; // More than available
        uint256 deadline = block.timestamp + 3600;
        string memory signContext = "test_claim_002";

        bytes memory signature = signTrading(user1, address(gameToken1), claimAmount, signContext, deadline);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        fortuna.claimPairedTokenRewards{value: BNB_FEE}(
            address(gameToken1), claimAmount, deadline, signContext, signature
        );
    }

    function testClaimPairedTokenRewardsExpiredSignature() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        // Deposit some tokens first
        uint256 depositAmount = MIN_DEPOSIT * 2;
        vm.deal(user1, BNB_FEE * 2); // Need BNB for deposit and claimPairedTokenRewards
        vm.prank(user1);
        fortuna.deposit(address(gameToken1), depositAmount);

        uint256 claimAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp - 1; // Expired
        string memory signContext = "test_claim_003";

        bytes memory signature = signTrading(user1, address(gameToken1), claimAmount, signContext, deadline);

        vm.prank(user1);
        vm.expectRevert(SignatureExpired.selector);
        fortuna.claimPairedTokenRewards{value: BNB_FEE}(
            address(gameToken1), claimAmount, deadline, signContext, signature
        );
    }

    // ============ swapTokensForTokens Tests ============
    function testSwapTokensForTokens() public {
        // Setup pancake swap pair
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 swapAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;

        uint256 userAgtBalanceBefore = agt.balanceOf(user1);
        uint256 userFusdBalanceBefore = fusd.balanceOf(user1);

        vm.expectEmit(true, true, true, false);
        emit Swap(user1, address(agt), address(fusd), swapAmount, 0);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.swapTokensForTokens{value: BNB_FEE}(address(agt), address(fusd), swapAmount, user1, deadline);

        // Verify tokens were swapped
        assertEq(agt.balanceOf(user1), userAgtBalanceBefore - swapAmount);
        assertTrue(fusd.balanceOf(user1) > userFusdBalanceBefore); // Received some FUSD
    }

    function testSwapTokensForTokensInvalidPair() public {
        uint256 swapAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(OnlySellPathsAllowed.selector);
        fortuna.swapTokensForTokens{value: BNB_FEE}(
            address(gameToken1), address(gameToken2), swapAmount, user1, deadline
        );
    }

    function testSwapTokensForTokensZeroAmount() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 deadline = block.timestamp + 3600;

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(AmountZero.selector);
        fortuna.swapTokensForTokens{value: BNB_FEE}(address(gameToken1), address(agt), 0, user1, deadline);
    }

    function testSwapTokensForTokensExpired() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 swapAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp - 1; // Expired

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        vm.expectRevert(SignatureExpired.selector);
        fortuna.swapTokensForTokens{value: BNB_FEE}(address(gameToken1), address(agt), swapAmount, user1, deadline);
    }

    function testSwapTokensForTokensWithUSDT() public {
        uint256 swapAmount = MIN_DEPOSIT;
        uint256 deadline = block.timestamp + 3600;

        uint256 userFusdBalanceBefore = fusd.balanceOf(user1);
        uint256 userUsdtBalanceBefore = usdt.balanceOf(user1);

        vm.deal(user1, BNB_FEE);
        vm.prank(user1);
        fortuna.swapTokensForTokens{value: BNB_FEE}(address(fusd), address(usdt), swapAmount, user1, deadline);

        // Verify the swap happened (FUSD -> USDT)
        assertEq(fusd.balanceOf(user1), userFusdBalanceBefore - swapAmount);
        assertTrue(usdt.balanceOf(user1) > userUsdtBalanceBefore);
    }

    // ============ Utility Functions Tests ============
    function testValidToken() public view {
        assertTrue(fortuna.validToken(address(gameToken1)));
        assertTrue(fortuna.validToken(address(gameToken2)));
        assertFalse(fortuna.validToken(address(0)));
    }

    function testValidTokenPair() public {
        // Add pancake swap info
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        assertTrue(fortuna.validTokenPair(address(gameToken1), address(agt)));
        assertFalse(fortuna.validTokenPair(address(gameToken1), address(gameToken2)));
        assertFalse(fortuna.validTokenPair(address(gameToken2), address(agt)));
    }

    function testGetAmountsOut() public {
        // Setup pair
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        uint256 amountIn = MIN_DEPOSIT;
        uint256 estimatedOut = fortuna.getAmountsOut(address(gameToken1), address(agt), amountIn);

        assertTrue(estimatedOut > 0);
        // Based on our mock router, it should be around 98% of input (2% slippage)
        assertTrue(estimatedOut >= (amountIn * 97) / 100);
    }

    function testGetAmountsOutInvalidPair() public {
        uint256 amountIn = MIN_DEPOSIT;
        uint256 est = fortuna.getAmountsOut(address(gameToken1), address(gameToken2), amountIn);
        assertTrue(est > 0);
    }

    // ============ Additional setBuyFee Tests ============
    function testSetBuyFee() public {
        fortuna.addPancakeSwapInfos(address(gameToken1), address(agt));

        fortuna.setBuyFee(address(gameToken1), true, 1000); // 10% fee

        (,, uint256 buyFeePercent, bool buySupported) = fortuna.pancakeSwapInfos(address(gameToken1));
        assertEq(buyFeePercent, 1000);
        assertTrue(buySupported);
    }

    function testSetBuyFeeUnsupportedToken() public {
        vm.expectRevert("Token not supported");
        fortuna.setBuyFee(address(gameToken1), true, 1000);
    }

    // ============ Merkle Root Tests ============
    function testSetMerkleRoot() public {
        bytes32 newRoot = keccak256("test_merkle_root");
        uint256 nonce = fortuna.oracleNonce() + 1;

        bytes32 message = keccak256(abi.encodePacked(block.chainid, newRoot, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, false, false, true);
        emit MerkleRootUpdated(operator, bytes32(0), newRoot, block.timestamp);

        vm.prank(operator);
        fortuna.setMerkleRoot(newRoot, signature);

        assertEq(fortuna.merkleRoot(), newRoot);
    }

    function testVerifyMerkleProof() public {
        // Set a merkle root first
        bytes32 newRoot = keccak256("test_merkle_root");
        uint256 nonce = fortuna.oracleNonce() + 1;

        bytes32 message = keccak256(abi.encodePacked(block.chainid, newRoot, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(oraclePrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(operator);
        fortuna.setMerkleRoot(newRoot, signature);

        // Test verification (this is a simple test as we set root to keccak256("test_merkle_root"))
        bytes32[] memory proof = new bytes32[](0);
        bytes32 leaf = keccak256("test_merkle_root");

        assertTrue(fortuna.verifyMerkleProof(proof, leaf));
        assertFalse(fortuna.verifyMerkleProof(proof, keccak256("different_leaf")));
    }
}

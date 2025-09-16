// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AGT.sol";

contract AGTTest is Test {
    AGT public agt;
    address public owner;
    address public operationWallet;
    address public minter;
    address public burner;
    address public user1;
    address public user2;
    address public swapPair;
    address public nonExemptUser;

    uint256 public constant INITIAL_SUPPLY = 1000000; // 1 million tokens
    uint256 public constant DEFAULT_FEE_BPS = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000; // 100%

    event MinterUpdated(address indexed account, bool status);
    event BurnerUpdated(address indexed account, bool status);
    event FeeExemptUpdated(address indexed account, bool status);
    event SwapPairUpdated(address indexed pair, bool status);
    event FeeWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event NodeCardFeeReceived(address indexed from, address indexed feeWallet, uint256 amount);

    function setUp() public {
        owner = address(this);
        operationWallet = makeAddr("operationWallet");
        minter = makeAddr("minter");
        burner = makeAddr("burner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        swapPair = makeAddr("swapPair");
        nonExemptUser = makeAddr("nonExemptUser");

        // Deploy AGT with initial supply
        agt = new AGT(INITIAL_SUPPLY, address(0x0));
        // Set required addresses for fee distribution to avoid zero-address transfers
        agt.setFeeWallet(operationWallet);
        agt.setGameContract(operationWallet);
    }

    // ============ Deployment Tests ============
    function testDeployment() public view {
        assertEq(agt.name(), "AIFortuna Game Token");
        assertEq(agt.symbol(), "AGT");
        assertEq(agt.decimals(), 18);
        assertEq(agt.totalSupply(), INITIAL_SUPPLY * 10 ** 18);
        assertEq(agt.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18);
        assertEq(agt.owner(), owner);
        assertEq(agt.feeBps(), DEFAULT_FEE_BPS);
        assertTrue(agt.feeExempt(owner));
    }

    // ============ Ownership Tests ============
    function testOnlyOwnerFunctions() public {
        vm.prank(user1);
        vm.expectRevert();
        agt.setFeeExempt(user1, true);

        vm.prank(user1);
        vm.expectRevert();
        agt.setSwapPair(swapPair, true);

        vm.prank(user1);
        vm.expectRevert();
        agt.setFeeWallet(operationWallet);

        vm.prank(user1);
        vm.expectRevert();
        agt.setFeeBps(500);
    }

    // ============ Fee Exempt Tests ============
    function testSetFeeExempt() public {
        assertFalse(agt.feeExempt(user1));

        vm.expectEmit(true, false, false, true);
        emit FeeExemptUpdated(user1, true);
        agt.setFeeExempt(user1, true);

        assertTrue(agt.feeExempt(user1));
    }

    // ============ Swap Pair Tests ============
    function testSetSwapPair() public {
        assertFalse(agt.swapPairs(swapPair));

        vm.expectEmit(true, false, false, true);
        emit SwapPairUpdated(swapPair, true);
        agt.setSwapPair(swapPair, true);

        assertTrue(agt.swapPairs(swapPair));
    }

    // ============ Operation Wallet Tests ============
    function testSetOperationWallet() public {
        vm.expectRevert("op zero");
        agt.setFeeWallet(address(0));

        address newOp = makeAddr("operationWallet2");
        // first already set in setUp to operationWallet; now change to newOp
        vm.expectEmit(true, true, false, true);
        emit FeeWalletUpdated(operationWallet, newOp);
        vm.expectEmit(true, false, false, true);
        emit FeeExemptUpdated(newOp, true);
        agt.setFeeWallet(newOp);

        assertEq(agt.feeWallet(), newOp);
        assertTrue(agt.feeExempt(newOp));
    }

    // ============ Fee Configuration Tests ============
    function testSetFeeBps() public {
        vm.expectEmit(false, false, false, true);
        emit FeeBpsUpdated(DEFAULT_FEE_BPS, 500);
        agt.setFeeBps(500);

        assertEq(agt.feeBps(), 500);

        // Setting fee above 1000 should revert per contract
        vm.expectRevert("fee > denom");
        agt.setFeeBps(FEE_DENOMINATOR);
    }

    // ============ Transfer Fee Tests ============
    function testTransferWithoutFee() public {
        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 balanceBefore = agt.balanceOf(user1);

        agt.transfer(user1, transferAmount);

        assertEq(agt.balanceOf(user1), balanceBefore + transferAmount);
        assertEq(agt.balanceOf(owner), INITIAL_SUPPLY * 10 ** 18 - transferAmount);
    }

    function testTransferToSwapPairWithFee() public {
        // Setup
        agt.setSwapPair(swapPair, true);
        agt.setFeeWallet(operationWallet);
        agt.setGameContract(operationWallet);

        uint256 transferAmount = 1000 * 10 ** 18;

        // Give tokens to non-exempt user
        agt.transfer(nonExemptUser, transferAmount);

        uint256 expectedFee = (transferAmount * DEFAULT_FEE_BPS) / FEE_DENOMINATOR;
        uint256 expectedReceived = transferAmount - expectedFee;

        uint256 swapPairBalanceBefore = agt.balanceOf(swapPair);
        uint256 operationBalanceBefore = agt.balanceOf(operationWallet);

        uint256 expectedGameFee = (expectedFee * 9000) / FEE_DENOMINATOR; // 90% of fee to gameContract
        uint256 expectedTeamFee = expectedFee - expectedGameFee;

        vm.expectEmit(true, true, false, true);
        emit NodeCardFeeReceived(nonExemptUser, operationWallet, expectedGameFee);

        vm.prank(nonExemptUser);
        agt.transfer(swapPair, transferAmount);

        assertEq(agt.balanceOf(swapPair), swapPairBalanceBefore + expectedReceived);
        assertEq(agt.balanceOf(operationWallet), operationBalanceBefore + expectedGameFee + expectedTeamFee);
    }

    function testTransferFromSwapPairShouldRevert() public {
        // Setup swap pair
        agt.setSwapPair(swapPair, true);

        // Give tokens to swap pair
        agt.transfer(swapPair, 1000 * 10 ** 18);

        // Try to buy from swap pair (should revert)
        vm.prank(swapPair);
        vm.expectRevert();
        agt.transfer(user1, 100 * 10 ** 18);
    }

    function testTransferFeeExemptUser() public {
        // Setup
        agt.setSwapPair(swapPair, true);
        agt.setFeeWallet(operationWallet);
        agt.setGameContract(operationWallet);
        agt.setFeeExempt(user1, true);

        uint256 transferAmount = 1000 * 10 ** 18;

        // Give tokens to fee exempt user
        agt.transfer(user1, transferAmount);

        uint256 swapPairBalanceBefore = agt.balanceOf(swapPair);
        uint256 operationBalanceBefore = agt.balanceOf(operationWallet);

        // Fee exempt user should not pay fees
        vm.prank(user1);
        agt.transfer(swapPair, transferAmount);

        assertEq(agt.balanceOf(swapPair), swapPairBalanceBefore + transferAmount);
        assertEq(agt.balanceOf(operationWallet), operationBalanceBefore); // No fee
    }

    function testTransferFromWithFee() public {
        // Setup
        agt.setSwapPair(swapPair, true);
        agt.setFeeWallet(operationWallet);

        uint256 transferAmount = 1000 * 10 ** 18;
        uint256 allowanceAmount = 2000 * 10 ** 18;

        // Give tokens to user1 and set allowance
        agt.transfer(user1, transferAmount);
        vm.prank(user1);
        agt.approve(user2, allowanceAmount);

        uint256 expectedFee = (transferAmount * DEFAULT_FEE_BPS) / FEE_DENOMINATOR;
        uint256 expectedReceived = transferAmount - expectedFee;

        uint256 swapPairBalanceBefore = agt.balanceOf(swapPair);
        uint256 operationBalanceBefore = agt.balanceOf(operationWallet);

        uint256 expectedGameFee2 = (expectedFee * 9000) / FEE_DENOMINATOR;
        uint256 expectedTeamFee2 = expectedFee - expectedGameFee2;

        vm.expectEmit(true, true, false, true);
        emit NodeCardFeeReceived(user1, operationWallet, expectedGameFee2);

        vm.prank(user2);
        agt.transferFrom(user1, swapPair, transferAmount);

        assertEq(agt.balanceOf(swapPair), swapPairBalanceBefore + expectedReceived);
        assertEq(agt.balanceOf(operationWallet), operationBalanceBefore + expectedGameFee2 + expectedTeamFee2);
        assertEq(agt.allowance(user1, user2), allowanceAmount - transferAmount);
    }

    function testTransferZeroAddress() public {
        vm.expectRevert("zero addr");
        agt.transfer(address(0), 100);

        // Test transferFrom with zero address
        agt.approve(user1, 1000);
        vm.prank(user1);
        vm.expectRevert("zero addr");
        agt.transferFrom(owner, address(0), 100);
    }

    // ============ Edge Cases Tests ============
    function testZeroFeeTransfer() public {
        // Set fee to 0
        agt.setFeeBps(0);
        agt.setSwapPair(swapPair, true);
        agt.setFeeWallet(operationWallet);

        uint256 transferAmount = 1000 * 10 ** 18;
        agt.transfer(nonExemptUser, transferAmount);

        uint256 swapPairBalanceBefore = agt.balanceOf(swapPair);
        uint256 operationBalanceBefore = agt.balanceOf(operationWallet);

        vm.prank(nonExemptUser);
        agt.transfer(swapPair, transferAmount);

        // Should transfer full amount without fee
        assertEq(agt.balanceOf(swapPair), swapPairBalanceBefore + transferAmount);
        assertEq(agt.balanceOf(operationWallet), operationBalanceBefore); // No fee
    }

    function testMaximumFeeTransfer() public {
        // Set fee to maximum allowed (1000 bps = 10%)
        agt.setFeeBps(DEFAULT_FEE_BPS);
        agt.setSwapPair(swapPair, true);
        agt.setFeeWallet(operationWallet);
        agt.setGameContract(operationWallet);

        uint256 transferAmount = 1000 * 10 ** 18;
        agt.transfer(nonExemptUser, transferAmount);

        uint256 swapPairBalanceBefore = agt.balanceOf(swapPair);
        uint256 operationBalanceBefore = agt.balanceOf(operationWallet);

        uint256 expectedFee = (transferAmount * DEFAULT_FEE_BPS) / FEE_DENOMINATOR;
        uint256 expectedReceived = transferAmount - expectedFee;
        uint256 expectedGameFee = (expectedFee * 9000) / FEE_DENOMINATOR;
        uint256 expectedTeamFee = expectedFee - expectedGameFee;

        vm.prank(nonExemptUser);
        agt.transfer(swapPair, transferAmount);

        assertEq(agt.balanceOf(swapPair), swapPairBalanceBefore + expectedReceived);
        assertEq(agt.balanceOf(operationWallet), operationBalanceBefore + expectedGameFee + expectedTeamFee);
    }

    // ============ Reentrancy Tests ============
    function testReentrancyProtection() public {
        // The contract uses ReentrancyGuard, so reentrancy attacks should be prevented
        // This is more of a smoke test since we can't easily test reentrancy without a malicious contract
        uint256 transferAmount = 1000 * 10 ** 18;
        agt.transfer(user1, transferAmount);

        vm.prank(user1);
        agt.transfer(user2, transferAmount);

        assertEq(agt.balanceOf(user2), transferAmount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./math/Smootherstep.sol";
import "./interfaces/ITreasuryHedge.sol";
import "./interfaces/IPancakeRouter02.sol";

/// @title Fortuna Treasury
/// @notice Holds FUSD & USDT reserves and performs hedge operations guided by smootherstep^gamma mapping.
contract Treasury is Ownable2StepUpgradeable, ReentrancyGuardUpgradeable, ITreasuryHedge {
    using SmootherstepMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public fusd;
    IERC20 public usdt;

    uint256 public gamma; // 1.0 default
    uint256 public feeToLPBps; // 10% of hedge amount added as LP (MVP placeholder, not yet auto-added)

    address[] public operators;
    mapping(address => bool) public operatorsMap;
    IPancakeRouter02 public pancakeRouter;
    address public lpToken;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant BPS = 10000;
    uint256 public slippageBps; // default 300 = 3%

    // price constants (scaled 1e18)
    uint256 public basePrice; // 0.05 * 1e18
    uint256 public upPrice; // 0.20 * 1e18
    uint256 public downPrice; // 0.025 * 1e18

    // events
    // Treasury.sol 添加更详细的事件
    event SwapExecuted(bool fusdToUsdt, uint256 amountIn, uint256 amountOut, bool isUpZone, uint256 timestamp);

    event LPAdded(
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 lpTokens,
        uint256 timestamp
    );
    event TreasuryInitialized(
        address indexed owner,
        address indexed fusd,
        address indexed usdt,
        uint256 basePrice,
        uint256 upPrice,
        uint256 downPrice,
        address pancakeRouter,
        address lpToken,
        uint256 timestamp
    );
    event OperatorAdded(address indexed operator, address indexed addedBy, uint256 timestamp);
    event OperatorRemoved(address indexed operator, address indexed removedBy, uint256 timestamp);
    event BasePriceUpdated(address indexed operator, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event UpPriceUpdated(address indexed operator, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event DownPriceUpdated(address indexed operator, uint256 oldPrice, uint256 newPrice, uint256 timestamp);
    event PancakeRouterUpdated(address indexed operator, address oldRouter, address newRouter, uint256 timestamp);
    event LpTokenUpdated(address indexed operator, address oldLpToken, address newLpToken, uint256 timestamp);
    event EmergencyWithdrawal(address indexed operator, address indexed token, uint256 amount, uint256 timestamp);

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
        address _fusd,
        address _usdt,
        uint256 _base,
        uint256 _up,
        uint256 _down,
        address _pancakeRouter,
        address _lpToken
    ) external initializer {
        __Ownable_init(_msgSender());
        __Ownable2Step_init();
        __ReentrancyGuard_init();

        fusd = IERC20(_fusd);
        usdt = IERC20(_usdt);
        basePrice = _base;
        upPrice = _up;
        downPrice = _down;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        lpToken = _lpToken;
        gamma = 1e18; // default 1.0
        feeToLPBps = 1000;
        slippageBps = 300;

        emit TreasuryInitialized(msg.sender, _fusd, _usdt, _base, _up, _down, _pancakeRouter, _lpToken, block.timestamp);
    }

    modifier onlyOperator() {
        require(operatorsMap[msg.sender], "not operator");
        _;
    }

    function setOperator(address newOperator) external onlyOwner {
        if (!operatorsMap[newOperator]) {
            operators.push(newOperator);
            operatorsMap[newOperator] = true;
            emit OperatorAdded(newOperator, msg.sender, block.timestamp);
        }
    }

    function setOperator(address operator, bool enabled) external onlyOwner {
        if (enabled) {
            if (!operatorsMap[operator]) {
                operators.push(operator);
                operatorsMap[operator] = true;
                emit OperatorAdded(operator, msg.sender, block.timestamp);
            }
        } else {
            if (operatorsMap[operator]) {
                operatorsMap[operator] = false;
                emit OperatorRemoved(operator, msg.sender, block.timestamp);
            }
        }
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

    function setGamma(uint256 _gamma) external onlyOwner {
        require(_gamma >= 5e17 && _gamma <= 3e18, "gamma range");
        uint256 oldGamma = gamma;
        emit GammaUpdated(oldGamma, _gamma);
        gamma = _gamma;
    }

    function setFeeToLP(uint256 pctBps) external onlyOwner {
        uint256 oldFee = feeToLPBps;
        emit FeeToLPUpdated(oldFee, pctBps);
        feeToLPBps = pctBps;
    }

    function setBasePrice(uint256 _basePrice) external onlyOwner {
        uint256 oldPrice = basePrice;
        basePrice = _basePrice;
        emit BasePriceUpdated(msg.sender, oldPrice, _basePrice, block.timestamp);
    }

    function setUpPrice(uint256 _upPrice) external onlyOwner {
        uint256 oldPrice = upPrice;
        upPrice = _upPrice;
        emit UpPriceUpdated(msg.sender, oldPrice, _upPrice, block.timestamp);
    }

    function setDownPrice(uint256 _downPrice) external onlyOwner {
        uint256 oldPrice = downPrice;
        downPrice = _downPrice;
        emit DownPriceUpdated(msg.sender, oldPrice, _downPrice, block.timestamp);
    }

    function setPancakeRouter(address _pancakeRouter) external onlyOwner {
        address oldRouter = address(pancakeRouter);
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
        emit PancakeRouterUpdated(msg.sender, oldRouter, _pancakeRouter, block.timestamp);
    }

    function setLpToken(address _lpToken) external onlyOwner {
        address oldLpToken = lpToken;
        lpToken = _lpToken;
        emit LpTokenUpdated(msg.sender, oldLpToken, _lpToken, block.timestamp);
    }

    function computeAlpha(HedgeParams memory p) public view override returns (uint256 alphaBps) {
        // Normalize t in [0,1]
        uint256 t;
        if (p.isUpZone) {
            if (p.price <= p.basePrice) t = 0;
            else if (p.price >= p.upPrice) t = 1e18;
            else t = ((p.price - p.basePrice) * 1e18) / (p.upPrice - p.basePrice);
        } else {
            if (p.price >= p.basePrice) t = 0;
            else if (p.price <= p.downPrice) t = 1e18;
            else t = ((p.basePrice - p.price) * 1e18) / (p.basePrice - p.downPrice);
        }
        uint256 s = t.smootherGamma(gamma); // 1e18
        // Four curves mapping:
        // Up zone: userBuy -> 50%->100%; userSell -> 45%->90%
        // Down zone: userBuy -> 50%->10%; userSell -> 50%->100%
        // Interpolate: alpha = 0.5 +/- 0.4 * s
        // Return in basis points (x 100%)
        if (p.isUpZone && p.isBuy) {
            // 0.5 -> 1
            alphaBps = 5000 + (5000 * s) / 1e18;
        } else if (p.isUpZone && !p.isBuy) {
            // up zone sell: 0.45 -> 0.95
            alphaBps = 5000 + (4500 * s) / 1e18;
        } else if (!p.isUpZone && p.isBuy) {
            // down zone buy: 0.5 -> 0.9
            alphaBps = 5000 - (4000 * s) / 1e18;
        } else {
            // down zone sell: 0.5 -> 1
            alphaBps = 5000 + (5000 * s) / 1e18;
        }
    }

    function execute(uint256 amount, bool isBuy) external override onlyOperator nonReentrant {
        address[] memory path = new address[](2);
        path[0] = address(fusd);
        path[1] = address(usdt);
        uint256 price = pancakeRouter.getAmountsOut(1e18, path)[1];

        // Construct hedge parameters
        HedgeParams memory hp = HedgeParams({
            price: price,
            basePrice: basePrice,
            upPrice: upPrice,
            downPrice: downPrice,
            isBuy: isBuy,
            isUpZone: price >= basePrice
        });

        _executeHedge(amount, hp);
    }

    function executeHedge(uint256 userAmount, HedgeParams calldata p)
        external
        override
        onlyOperator
        nonReentrant
        returns (uint256 hedgeAmount, uint256 alphaBps)
    {
        (hedgeAmount, alphaBps) = _executeHedge(userAmount, p);
    }

    function _executeHedge(uint256 userAmount, HedgeParams memory p)
        internal
        returns (uint256 hedgeAmount, uint256 alphaBps)
    {
        alphaBps = computeAlpha(p); // basis points
        hedgeAmount = (userAmount * alphaBps) / 10000;

        // Execute actual hedge based on user action and zone
        if (p.isBuy) {
            // User buying FUSD: Treasury needs to acquire more USDT to maintain reserves
            _executeUSDTAcquisition(hedgeAmount, p.isUpZone);
        } else {
            // User selling FUSD: Treasury may reduce USDT exposure or add to LP
            _executeUSDTReduction(hedgeAmount, p.isUpZone);
        }

        emit HedgeExecuted(p.isBuy, userAmount, hedgeAmount, alphaBps, p.price, p.isUpZone);
    }

    /// @notice Execute USDT acquisition for hedge (when users buy FUSD)
    /// @param hedgeAmount Amount to hedge in USDT terms
    /// @param isUpZone Whether price is in up zone
    function _executeUSDTAcquisition(uint256 hedgeAmount, bool isUpZone) internal {
        uint256 treasuryFUSD = fusd.balanceOf(address(this));
        uint256 lpAmount = (hedgeAmount * feeToLPBps) / BPS;
        uint256 swapAmount = hedgeAmount - lpAmount;

        if (treasuryFUSD >= hedgeAmount) {
            _swap(true, swapAmount, isUpZone); // FUSD -> USDT
        }

        if (lpAmount > 0 && treasuryFUSD >= lpAmount) {
            // Add portion to LP (10% default)
            _addLP(address(fusd), address(usdt), lpAmount);
        }
    }

    /// @notice Execute USDT reduction for hedge (when users sell FUSD)
    /// @param hedgeAmount Amount to hedge in USDT terms
    /// @param isUpZone Whether price is in up zone
    function _executeUSDTReduction(uint256 hedgeAmount, bool isUpZone) internal {
        uint256 treasuryUSDT = usdt.balanceOf(address(this));
        uint256 lpAmount = (hedgeAmount * feeToLPBps) / BPS;
        uint256 swapAmount = hedgeAmount - lpAmount;

        if (treasuryUSDT >= swapAmount && swapAmount > 0) {
            // Use USDT to acquire FUSD (reduce USDT exposure)
            _swap(false, swapAmount, isUpZone); // USDT -> FUSD
        }

        if (lpAmount > 0 && treasuryUSDT >= lpAmount) {
            // Add portion to LP (10% default)
            _addLP(address(usdt), address(fusd), lpAmount);
        }
    }

    /// @notice swap execution (placeholder for actual router integration)
    /// @param fusdToUsdt Direction of swap
    /// @param amount Amount being swapped
    /// @param isUpZone Price zone context
    function _swap(bool fusdToUsdt, uint256 amount, bool isUpZone) internal {
        address[] memory path = new address[](2);
        if (fusdToUsdt) {
            path[0] = address(fusd);
            path[1] = address(usdt);
        } else {
            path[0] = address(usdt);
            path[1] = address(fusd);
        }
        uint256 tokenBalanceBefore = IERC20(path[1]).balanceOf(address(this));
        // approve exact amount for the input token
        IERC20(path[0]).approve(address(pancakeRouter), 0);
        IERC20(path[0]).approve(address(pancakeRouter), amount);
        uint256 expectedOut = pancakeRouter.getAmountsOut(amount, path)[1];
        uint256 minOut = (expectedOut * (BPS - slippageBps)) / BPS;
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, minOut, path, address(this), block.timestamp
        );
        uint256 tokenBalanceAfter = IERC20(path[1]).balanceOf(address(this));
        uint256 amountOut = tokenBalanceAfter - tokenBalanceBefore;
        emit SwapExecuted(fusdToUsdt, amount, amountOut, isUpZone, block.timestamp);
    }

    function _addLP(address inputToken, address outputToken, uint256 amount) internal {
        // 取10%,来进行添加LP操作.
        uint256 amountIn = amount / 2;

        address[] memory path = new address[](2);
        path[0] = inputToken;
        path[1] = outputToken;

        uint256 deadline = block.timestamp;
        uint256 tokenBalanceBefore = IERC20(outputToken).balanceOf(address(this));
        // approve exact amount for swap leg
        IERC20(inputToken).approve(address(pancakeRouter), 0);
        IERC20(inputToken).approve(address(pancakeRouter), amountIn);
        uint256 expectedOut = pancakeRouter.getAmountsOut(amountIn, path)[1];
        uint256 minOut = (expectedOut * (BPS - slippageBps)) / BPS;
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn, minOut, path, address(this), deadline
        );
        uint256 tokenBalanceAfter = IERC20(outputToken).balanceOf(address(this));
        uint256 amountOut = tokenBalanceAfter - tokenBalanceBefore;
        // approve exact amounts for addLiquidity
        IERC20(inputToken).approve(address(pancakeRouter), 0);
        IERC20(inputToken).approve(address(pancakeRouter), amountIn);
        IERC20(outputToken).approve(address(pancakeRouter), 0);
        IERC20(outputToken).approve(address(pancakeRouter), amountOut);
        pancakeRouter.addLiquidity(inputToken, outputToken, amountIn, amountOut, 0, 0, address(this), deadline);
        //Burn 的LP-pair-token
        uint256 lp_to_burn = IERC20(lpToken).balanceOf(address(this));
        IERC20(lpToken).transfer(DEAD, lp_to_burn);

        emit LPAdded(path[0], path[1], amountIn, amountOut, lp_to_burn, block.timestamp);
    }
}

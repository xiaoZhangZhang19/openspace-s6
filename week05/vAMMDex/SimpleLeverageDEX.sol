// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title SimpleLeverageDEX
 * @dev 一个基于vAMM的简单杠杆交易DEX
 *
 * 本合约使用vAMM机制模拟杠杆交易市场，价格由X和Y的储备比例决定：
 * - X代表基础资产（如ETH）
 * - Y代表计价资产（如USDC）
 * - 价格表示为 price = Y/X
 * 
 * 在这个实现中：
 * - 做多：减少X储备，增加Y储备，导致价格上升（Y/X增加）
 * - 做空：增加X储备，减少Y储备，导致价格下降（Y/X减少）
 * 
 * 这符合传统市场的价格行为：做多推高价格，做空压低价格。
 */
contract SimpleLeverageDEX is ReentrancyGuard {
    using Math for uint256;

    // 状态变量
    address public immutable collateralToken; // 保证金代币
    uint8 public immutable collateralDecimals; // 保证金代币的小数位数
    uint256 public constant PRICE_PRECISION = 1e18;
    uint256 public constant FEE_PRECISION = 10000; // 0.01% = 1
    uint256 public immutable openFee; // 开仓手续费率
    uint256 public immutable closeFee; // 平仓手续费率
    uint256 public immutable liquidationThreshold; // 清算阈值
    uint256 public immutable maxLeverage; // 最大杠杆倍数

    // vAMM 参数
    uint256 public immutable initialPrice;
    uint256 public vammReserveX; // 虚拟资产X储备（基础资产，如ETH）
    uint256 public vammReserveY; // 虚拟资产Y储备（计价资产，如USDC）

    // 精度转换相关
    uint256 public immutable collateralPrecision; // 保证金代币精度因子 (10^decimals)
    uint256 public immutable precisionScaleFactor; // 精度缩放因子 (10^(18-decimals) 或 1)

    // 用户仓位结构
    struct Position {
        uint256 margin; // 保证金数量
        uint256 size; // 仓位大小
        uint256 entryPrice; // 开仓价格
        uint256 leverage; // 杠杆倍数
        bool isLong; // 多空方向，true为多，false为空
        bool isOpen; // 仓位是否开启
    }

    // 用户地址 => 用户仓位
    mapping(address => Position) public positions;

    // 事件
    event PositionOpened(address indexed user, uint256 margin, uint256 size, uint256 entryPrice, uint256 leverage, bool isLong);
    event PositionClosed(address indexed user, uint256 margin, uint256 size, uint256 exitPrice, int256 pnl);
    event PositionLiquidated(address indexed user, address indexed liquidator, uint256 exitPrice);

    /**
     * @dev 构造函数
     * @param _collateralToken 保证金代币地址
     * @param _initialPrice 初始价格
     * @param _vammReserveX 初始虚拟资产X储备
     * @param _openFee 开仓手续费率
     * @param _closeFee 平仓手续费率
     * @param _liquidationThreshold 清算阈值
     * @param _maxLeverage 最大杠杆倍数
     */
    constructor(
        address _collateralToken,
        uint256 _initialPrice,
        uint256 _vammReserveX,
        uint256 _openFee,
        uint256 _closeFee,
        uint256 _liquidationThreshold,
        uint256 _maxLeverage
    ) {
        collateralToken = _collateralToken;
        initialPrice = _initialPrice;
        
        // 获取代币精度
        collateralDecimals = IERC20Metadata(_collateralToken).decimals();
        collateralPrecision = 10 ** uint256(collateralDecimals);
        
        // 如果代币精度不是18，计算缩放因子
        if (collateralDecimals < 18) {
            precisionScaleFactor = 10 ** (18 - uint256(collateralDecimals));
        } else {
            precisionScaleFactor = 1;
        }
        
        vammReserveX = _vammReserveX;
        vammReserveY = _vammReserveX * _initialPrice / PRICE_PRECISION;
        openFee = _openFee;
        closeFee = _closeFee;
        liquidationThreshold = _liquidationThreshold;
        maxLeverage = _maxLeverage;
    }

    /**
     * @dev 获取当前vAMM价格
     * @return 当前价格
     */
    function getPrice() public view returns (uint256) {
        return vammReserveY * PRICE_PRECISION / vammReserveX;
    }

    /**
     * @dev 将代币金额按照正确精度转换为内部计算精度
     * @param _amount 原始代币金额
     * @return 调整后的金额
     */
    function toInternalAmount(uint256 _amount) internal view returns (uint256) {
        return _amount * precisionScaleFactor;
    }
    
    /**
     * @dev 将内部计算金额转换回代币精度
     * @param _amount 内部金额
     * @return 转换后的代币金额
     */
    function toTokenAmount(uint256 _amount) internal view returns (uint256) {
        return _amount / precisionScaleFactor;
    }

    /**
     * @dev 计算交易滑点和交易后价格
     * @param _amount 交易数量
     * @param _isLong 是否做多
     * @return 交易后价格
     *
     * 注意：
     * - 做多时，减少X储备，增加Y储备，价格上升
     * - 做空时，增加X储备，减少Y储备，价格下降
     */
    function _getTradePrice(uint256 _amount, bool _isLong) private view returns (uint256) {
        uint256 k = vammReserveX * vammReserveY;
        uint256 newReserveX;
        uint256 newReserveY;
        
        if (_isLong) {
            // 做多，直接减少X，让价格上升
            // 保证X不会减至0
            uint256 amountX = _amount > vammReserveX / 2 ? vammReserveX / 2 : _amount;
            newReserveX = vammReserveX - amountX;
            newReserveY = k / newReserveX;
        } else {
            // 做空，直接增加X，让价格下降
            newReserveX = vammReserveX + _amount;
            newReserveY = k / newReserveX;
        }
        
        return newReserveY * PRICE_PRECISION / newReserveX;
    }

    /**
     * @dev 更新vAMM池子状态
     * @param _amount 交易数量
     * @param _isLong 是否做多
     */
    function _updateVamm(uint256 _amount, bool _isLong) private {
        uint256 k = vammReserveX * vammReserveY;
        
        if (_isLong) {
            // 做多，直接减少X，让价格上升
            // 保证X不会减至0
            // 如果交易量过大，对价格最大影响就是一半，vAMM的价格影响被限制了，不会因超大订单而过度波动
            uint256 amountX = _amount > vammReserveX / 2 ? vammReserveX / 2 : _amount;
            vammReserveX -= amountX;
            vammReserveY = k / vammReserveX;
        } else {
            // 做空，直接增加X，让价格下降
            // Y无限小最多就是价格接近0，但是X无限小就会导致除0错误，价格无限大，所以对Y没有限制
            vammReserveX += _amount;
            vammReserveY = k / vammReserveX;
        }
    }

    /**
     * @dev 开启杠杆头寸
     * @param _margin 保证金数量
     * @param _level 杠杆倍数
     * @param _isLong 是否做多
     *
     * 注意：开仓会对价格产生即时影响
     * - 做多：价格上升
     * - 做空：价格下降
     */
    function openPosition(uint256 _margin, uint256 _level, bool _isLong) external nonReentrant {
        // 检查杠杆倍数
        require(_level > 0 && _level <= maxLeverage, "Invalid leverage");
        // 检查保证金
        require(_margin > 0, "Margin must be greater than 0");
        // 检查用户是否已有仓位
        require(!positions[msg.sender].isOpen, "Position already opened");

        // 将保证金转换为内部精度
        uint256 internalMargin = toInternalAmount(_margin);
        
        // 计算仓位大小（保证金 * 杠杆倍数）
        uint256 positionSize = internalMargin * _level;
        
        // 计算开仓费用
        uint256 fee = positionSize * openFee / FEE_PRECISION;
        fee = toTokenAmount(fee); // 转换回代币精度以便转账
        
        // 转移保证金和手续费
        IERC20(collateralToken).transferFrom(msg.sender, address(this), _margin + fee);
        
        // 计算开仓价格（包含滑点）
        uint256 entryPrice = _getTradePrice(positionSize, _isLong);
        
        // 更新vAMM状态
        _updateVamm(positionSize, _isLong);
        
        // 记录用户仓位 - 保存内部精度的值
        positions[msg.sender] = Position({
            margin: internalMargin,
            size: positionSize,
            entryPrice: entryPrice,
            leverage: _level,
            isLong: _isLong,
            isOpen: true
        });
        
        emit PositionOpened(msg.sender, _margin, positionSize, entryPrice, _level, _isLong);
    }

    /**
     * @dev 计算仓位的PnL
     * @param _user 用户地址
     * @return pnl 盈亏
     * @return currentPrice 当前价格
     *
     * 盈亏计算逻辑：
     * - 多仓：当前价格 > 入场价格时盈利，反之亏损
     * - 空仓：当前价格 < 入场价格时盈利，反之亏损
     */
    function getPnL(address _user) public view returns (int256 pnl, uint256 currentPrice) {
        Position memory position = positions[_user];
        require(position.isOpen, "No position");
        
        currentPrice = getPrice();
        
        if (position.isLong) {
            // 多仓盈亏 = 仓位大小 * (当前价格 - 入场价格) / 入场价格
            if (currentPrice > position.entryPrice) {
                // 使用更大的乘数来增加盈利效果
                pnl = int256((position.size * 3 * (currentPrice - position.entryPrice)) / position.entryPrice);
            } else {
                pnl = -int256((position.size * (position.entryPrice - currentPrice)) / position.entryPrice);
            }
        } else {
            // 空仓盈亏 = 仓位大小 * (入场价格 - 当前价格) / 入场价格
            if (currentPrice < position.entryPrice) {
                // 使用更大的乘数来增加盈利效果
                pnl = int256((position.size * 3 * (position.entryPrice - currentPrice)) / position.entryPrice);
            } else {
                pnl = -int256((position.size * (currentPrice - position.entryPrice)) / position.entryPrice);
            }
        }
    }

    /**
     * @dev 关闭头寸并结算
     */
    function closePosition() external nonReentrant {
        Position memory position = positions[msg.sender];
        require(position.isOpen, "No position");
        
        // 获取当前价格和盈亏
        (int256 pnl, uint256 currentPrice) = getPnL(msg.sender);
        
        // 更新vAMM状态（关闭仓位方向与开仓相反）
        _updateVamm(position.size, !position.isLong);
        
        // 计算平仓费用
        uint256 closeFeeAmount = position.size * closeFee / FEE_PRECISION;
        
        // 计算用户应收金额（内部精度）
        uint256 returnAmountInternal;
        if (pnl > 0) {
            returnAmountInternal = position.margin + uint256(pnl) - closeFeeAmount;
        } else {
            // 如果亏损超过保证金，则返回0
            if (uint256(-pnl) >= position.margin) {
                returnAmountInternal = 0;
            } else {
                returnAmountInternal = position.margin - uint256(-pnl) - closeFeeAmount;
            }
        }
        
        // 转换回代币精度
        uint256 returnAmount = toTokenAmount(returnAmountInternal);
        
        // 删除仓位
        delete positions[msg.sender];
        
        // 转账给用户
        if (returnAmount > 0) {
            IERC20(collateralToken).transfer(msg.sender, returnAmount);
        }
        
        emit PositionClosed(msg.sender, toTokenAmount(position.margin), position.size, currentPrice, pnl);
    }

    /**
     * @dev 检查仓位是否可以被清算
     * @param _user 用户地址
     * @return 是否可清算
     */
    function canLiquidate(address _user) public view returns (bool) {
        Position memory position = positions[_user];
        if (!position.isOpen) return false;
        
        (int256 pnl,) = getPnL(_user);
        
        // 如果亏损超过保证金的指定比例，则可以清算
        // 降低清算门槛，原来是liquidationThreshold / FEE_PRECISION（80%），现在是50%
        return pnl < 0 && uint256(-pnl) >= position.margin * 5000 / FEE_PRECISION;
    }

    /**
     * @dev 清算头寸
     * @param _user 用户地址
     */
    function liquidatePosition(address _user) external nonReentrant {
        require(canLiquidate(_user), "Cannot liquidate");
        
        Position memory position = positions[_user];
        
        // 更新vAMM状态（关闭仓位方向与开仓相反）
        _updateVamm(position.size, !position.isLong);
        
        // 给清算人一些奖励（这里简化为保证金的一部分）
        uint256 liquidatorReward = toTokenAmount(position.margin / 10);
        if (liquidatorReward > 0) {
            IERC20(collateralToken).transfer(msg.sender, liquidatorReward);
        }
        
        // 删除仓位
        delete positions[_user];
        
        emit PositionLiquidated(_user, msg.sender, getPrice());
    }
} 
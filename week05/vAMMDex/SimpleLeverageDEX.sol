// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AggregatorV3Interface.sol";

/**
 * @title SimpleLeverageDEX
 * @dev 一个基于vAMM的简单杠杆交易DEX，使用Clearing House + Vault + Virtual AMM架构
 *
 * 本合约作为Clearing House，使用vAMM机制模拟杠杆交易市场：
 * - 用户资金存储在Vault中，而不是vAMM中
 * - vAMM仅作为价格引擎，基于常量乘积公式 x*y=k
 * - 价格表示为 price = Y/X
 * - 使用Chainlink预言机获取实时价格
 * 
 * 在这个实现中：
 * - 做多：减少X储备，增加Y储备，导致价格上升（Y/X增加）
 * - 做空：增加X储备，减少Y储备，导致价格下降（Y/X减少）
 */
contract SimpleLeverageDEX is ReentrancyGuard, Ownable {
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

    // Chainlink价格源
    AggregatorV3Interface public immutable priceFeed;
    uint8 public immutable priceFeedDecimals;

    // 全局统计
    uint256 public totalCollateral; // Vault中的总保证金
    uint256 public totalFees; // 累积的手续费

    // vAMM 参数
    uint256 public vammReserveX; // 虚拟资产X储备（基础资产，如ETH）
    uint256 public vammReserveY; // 虚拟资产Y储备（计价资产，如USDC）
    uint256 public constant TRADE_LIMIT_FACTOR = 2; // 交易量限制因子

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

    // 用户地址 => 仓位数量
    mapping(address => uint256) public positionCount;
    // 用户地址 => 仓位ID => 仓位
    mapping(address => mapping(uint256 => Position)) public positions;

    // 事件
    event PositionOpened(address indexed user, uint256 indexed positionId, uint256 margin, uint256 size, uint256 entryPrice, uint256 leverage, bool isLong);
    event PositionClosed(address indexed user, uint256 indexed positionId, uint256 margin, uint256 size, uint256 exitPrice, int256 pnl);
    event PositionLiquidated(address indexed user, uint256 indexed positionId, address indexed liquidator, uint256 exitPrice);
    event VaultDeposit(address indexed user, uint256 amount);
    event VaultWithdraw(address indexed user, uint256 amount);
    event VirtualAmmUpdated(uint256 reserveX, uint256 reserveY, uint256 price);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    /**
     * @dev 构造函数
     * @param _collateralToken 保证金代币地址
     * @param _priceFeed Chainlink价格源地址
     * @param _vammReserveX 初始虚拟资产X储备
     * @param _openFee 开仓手续费率
     * @param _closeFee 平仓手续费率
     * @param _liquidationThreshold 清算阈值
     * @param _maxLeverage 最大杠杆倍数
     */
    constructor(
        address _collateralToken,
        address _priceFeed,
        uint256 _vammReserveX,
        uint256 _openFee,
        uint256 _closeFee,
        uint256 _liquidationThreshold,
        uint256 _maxLeverage
    ) Ownable(msg.sender) {
        collateralToken = _collateralToken;
        
        // 设置Chainlink价格源
        priceFeed = AggregatorV3Interface(_priceFeed);
        priceFeedDecimals = priceFeed.decimals();
        
        // 获取代币精度
        collateralDecimals = IERC20Metadata(_collateralToken).decimals();
        collateralPrecision = 10 ** uint256(collateralDecimals);
        
        // 如果代币精度不是18，计算缩放因子
        if (collateralDecimals < 18) {
            precisionScaleFactor = 10 ** (18 - uint256(collateralDecimals));
        } else {
            precisionScaleFactor = 1;
        }
        
        // 获取当前价格初始化vAMM
        uint256 currentPrice = getChainlinkPrice();
        require(currentPrice > 0, "Invalid price from oracle");
        
        // 设置vAMM初始储备
        vammReserveX = _vammReserveX;
        vammReserveY = _vammReserveX * currentPrice / PRICE_PRECISION;
        
        openFee = _openFee;
        closeFee = _closeFee;
        liquidationThreshold = _liquidationThreshold;
        maxLeverage = _maxLeverage;
    }

    /**
     * @dev 从Chainlink获取当前价格
     * @return 当前价格（18位精度）
     */
    function getChainlinkPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Negative or zero price");
        
        // 转换为18位精度
        if (priceFeedDecimals < 18) {
            return uint256(price) * (10 ** (18 - priceFeedDecimals));
        } else if (priceFeedDecimals > 18) {
            return uint256(price) / (10 ** (priceFeedDecimals - 18));
        }
        return uint256(price);
    }

    /**
     * @dev 获取当前vAMM价格
     * @return 当前价格
     */
    function getPrice() public view returns (uint256) {
        return vammReserveY * PRICE_PRECISION / vammReserveX;
    }
    
    /**
     * @dev 更新vAMM价格以匹配Chainlink价格
     * 这个函数用于保持vAMM价格与外部市场一致
     */
    function updatePriceOracle() public {
        uint256 currentOraclePrice = getChainlinkPrice();
        uint256 currentVammPrice = getPrice();
        
        // 如果价格差异超过1%，则更新vAMM价格
        uint256 priceDiff = currentOraclePrice > currentVammPrice 
            ? currentOraclePrice - currentVammPrice 
            : currentVammPrice - currentOraclePrice;
            
        if (priceDiff * 100 > currentVammPrice) {
            // 保持X储备不变，调整Y储备来匹配新价格
            vammReserveY = vammReserveX * currentOraclePrice / PRICE_PRECISION;
            
            emit PriceUpdated(currentVammPrice, currentOraclePrice);
            emit VirtualAmmUpdated(vammReserveX, vammReserveY, getPrice());
        }
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
     * @dev 获取Vault中的实际代币余额
     * @return Vault中的代币余额
     */
    function getVaultBalance() public view returns (uint256) {
        return IERC20(collateralToken).balanceOf(address(this));
    }

    /**
     * @dev 计算交易滑点和交易后价格
     * @param _amount 交易数量
     * @param _isLong 是否做多
     * @return 交易后价格
     */
    function _getTradePrice(uint256 _amount, bool _isLong) private view returns (uint256) {
        uint256 k = vammReserveX * vammReserveY;
        uint256 newReserveX;
        uint256 newReserveY;
        
        if (_isLong) {
            // 做多，减少X储备，价格上升
            uint256 maxImpact = vammReserveX / TRADE_LIMIT_FACTOR;
            uint256 amountX = _amount > maxImpact ? maxImpact : _amount;
            newReserveX = vammReserveX - amountX;
            newReserveY = k / newReserveX;
        } else {
            // 做空，增加X储备，价格下降
            uint256 maxImpact = vammReserveX / TRADE_LIMIT_FACTOR;
            uint256 amountX = _amount > maxImpact ? maxImpact : _amount;
            newReserveX = vammReserveX + amountX;
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
            // 做多，减少X储备，价格上升
            // 通过限制单笔交易可以影响的最大储备量，防止价格暴涨或暴跌，保证系统稳定
            uint256 maxImpact = vammReserveX / TRADE_LIMIT_FACTOR;
            uint256 amountX = _amount > maxImpact ? maxImpact : _amount;
            vammReserveX -= amountX;
            vammReserveY = k / vammReserveX;
        } else {
            // 做空，增加X储备，价格下降
            uint256 maxImpact = vammReserveX / TRADE_LIMIT_FACTOR;
            uint256 amountX = _amount > maxImpact ? maxImpact : _amount;
            vammReserveX += amountX;
            vammReserveY = k / vammReserveX;
        }
        
        // 发出vAMM更新事件
        emit VirtualAmmUpdated(vammReserveX, vammReserveY, getPrice());
    }

    /**
     * @dev 开启杠杆头寸
     * @param _margin 保证金数量
     * @param _level 杠杆倍数
     * @param _isLong 是否做多
     * @return positionId 新开仓位的ID
     */
    function openPosition(uint256 _margin, uint256 _level, bool _isLong) external nonReentrant returns (uint256) {
        // 更新价格与外部市场同步
        updatePriceOracle();
        
        // 检查杠杆倍数
        require(_level > 0 && _level <= maxLeverage, "Invalid leverage");
        // 检查保证金
        require(_margin > 0, "Margin must be greater than 0");

        // 将保证金转换为内部精度
        uint256 internalMargin = toInternalAmount(_margin);
        
        // 计算仓位大小（保证金 * 杠杆倍数）
        uint256 positionSize = internalMargin * _level;
        
        // 计算开仓费用
        uint256 fee = positionSize * openFee / FEE_PRECISION;
        fee = toTokenAmount(fee); // 转换回代币精度以便转账
        
        // 转移保证金和手续费到Vault（此合约）
        IERC20(collateralToken).transferFrom(msg.sender, address(this), _margin + fee);
        
        // 更新Vault状态
        totalCollateral += _margin;
        totalFees += fee;
        emit VaultDeposit(msg.sender, _margin + fee);
        
        // 计算开仓价格（包含滑点）
        uint256 entryPrice = _getTradePrice(positionSize, _isLong);
        
        // 更新vAMM状态
        _updateVamm(positionSize, _isLong);
        
        // 生成新的仓位ID
        uint256 positionId = positionCount[msg.sender];
        positionCount[msg.sender] = positionId + 1;
        
        // 记录用户仓位 - 保存内部精度的值
        positions[msg.sender][positionId] = Position({
            margin: internalMargin,
            size: positionSize,
            entryPrice: entryPrice,
            leverage: _level,
            isLong: _isLong,
            isOpen: true
        });
        
        emit PositionOpened(msg.sender, positionId, _margin, positionSize, entryPrice, _level, _isLong);
        
        return positionId;
    }

    /**
     * @dev 计算仓位的PnL
     * @param _user 用户地址
     * @param _positionId 仓位ID
     * @return pnl 盈亏
     * @return currentPrice 当前价格
     */
    function getPnL(address _user, uint256 _positionId) public view returns (int256 pnl, uint256 currentPrice) {
        Position memory position = positions[_user][_positionId];
        require(position.isOpen, "No position");
        
        currentPrice = getPrice();
        
        if (position.isLong) {
            // 多仓盈亏 = 仓位大小 * (当前价格 - 入场价格) / 入场价格
            if (currentPrice > position.entryPrice) {
                pnl = int256((position.size * (currentPrice - position.entryPrice)) / position.entryPrice);
            } else {
                pnl = -int256((position.size * (position.entryPrice - currentPrice)) / position.entryPrice);
            }
        } else {
            // 空仓盈亏 = 仓位大小 * (入场价格 - 当前价格) / 入场价格
            if (currentPrice < position.entryPrice) {
                pnl = int256((position.size * (position.entryPrice - currentPrice)) / position.entryPrice);
            } else {
                pnl = -int256((position.size * (currentPrice - position.entryPrice)) / position.entryPrice);
            }
        }
    }

    /**
     * @dev 关闭头寸并结算
     * @param _positionId 仓位ID
     */
    function closePosition(uint256 _positionId) external nonReentrant {
        // 更新价格与外部市场同步
        updatePriceOracle();
        
        Position memory position = positions[msg.sender][_positionId];
        require(position.isOpen, "No position");
        
        // 获取当前价格和盈亏
        (int256 pnl, uint256 currentPrice) = getPnL(msg.sender, _positionId);
        
        // 更新vAMM状态（关闭仓位方向与开仓相反）
        _updateVamm(position.size, !position.isLong);
        
        // 计算平仓费用
        uint256 closeFeeAmount = position.size * closeFee / FEE_PRECISION;
        uint256 tokenCloseFee = toTokenAmount(closeFeeAmount);
        totalFees += tokenCloseFee;
        
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
        uint256 marginAmount = toTokenAmount(position.margin);
        
        // 更新Vault状态
        totalCollateral -= marginAmount;
        
        // 删除仓位
        delete positions[msg.sender][_positionId];
        
        // 从Vault转账给用户
        if (returnAmount > 0) {
            IERC20(collateralToken).transfer(msg.sender, returnAmount);
            emit VaultWithdraw(msg.sender, returnAmount);
        }
        
        emit PositionClosed(msg.sender, _positionId, marginAmount, position.size, currentPrice, pnl);
    }

    /**
     * @dev 检查仓位是否可以被清算
     * @param _user 用户地址
     * @param _positionId 仓位ID
     * @return 是否可清算
     */
    function canLiquidate(address _user, uint256 _positionId) public view returns (bool) {
        Position memory position = positions[_user][_positionId];
        if (!position.isOpen) return false;
        
        (int256 pnl,) = getPnL(_user, _positionId);
        
        // 如果亏损超过保证金的指定比例，则可以清算
        return pnl < 0 && uint256(-pnl) >= position.margin * liquidationThreshold / FEE_PRECISION;
    }

    /**
     * @dev 清算头寸
     * @param _user 用户地址
     * @param _positionId 仓位ID
     */
    function liquidatePosition(address _user, uint256 _positionId) external nonReentrant {
        // 更新价格与外部市场同步
        updatePriceOracle();
        
        require(canLiquidate(_user, _positionId), "Cannot liquidate");
        
        Position memory position = positions[_user][_positionId];
        uint256 marginAmount = toTokenAmount(position.margin);
        
        // 更新vAMM状态（关闭仓位方向与开仓相反）
        _updateVamm(position.size, !position.isLong);
        
        // 给清算人一些奖励（保证金的一部分）
        uint256 liquidatorReward = marginAmount / 10;
        
        // 更新Vault状态
        totalCollateral -= marginAmount;
        
        // 删除仓位
        delete positions[_user][_positionId];
        
        // 从Vault转账给清算人
        if (liquidatorReward > 0) {
            IERC20(collateralToken).transfer(msg.sender, liquidatorReward);
            emit VaultWithdraw(msg.sender, liquidatorReward);
        }
        
        emit PositionLiquidated(_user, _positionId, msg.sender, getPrice());
    }
    
    /**
     * @dev 提取费用（仅限所有者）
     * @param _amount 提取金额
     */
    function withdrawFees(uint256 _amount) external onlyOwner {
        require(_amount <= totalFees, "Amount exceeds available fees");
        totalFees -= _amount;
        IERC20(collateralToken).transfer(owner(), _amount);
        emit VaultWithdraw(owner(), _amount);
    }
    
    /**
     * @dev 获取系统状态
     * @return vaultBalance Vault余额
     * @return collateralTotal 总保证金
     * @return feesTotal 总手续费
     * @return currentPrice 当前价格
     * @return oraclePrice 预言机价格
     */
    function getSystemStatus() external view returns (
        uint256 vaultBalance,
        uint256 collateralTotal,
        uint256 feesTotal,
        uint256 currentPrice,
        uint256 oraclePrice
    ) {
        return (
            getVaultBalance(),
            totalCollateral,
            totalFees,
            getPrice(),
            getChainlinkPrice()
        );
    }
} 
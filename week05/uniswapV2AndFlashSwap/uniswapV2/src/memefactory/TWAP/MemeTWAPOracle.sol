// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Meme代币TWAP价格预言机
 * @dev 基于Uniswap V2的价格累积功能，计算代币的时间加权平均价格(TWAP)
 * @notice 该合约可以抵抗价格操纵，因为它使用时间加权平均价格而不是即时价格
 */
contract MemeTWAPOracle is Ownable {
    // Uniswap V2工厂合约
    IUniswapV2Factory public immutable factory;
    // WETH合约地址
    address public immutable weth;

    // 代币到价格观察点的映射
    struct Observation {
        uint256 timestamp;
        uint256 price0Cumulative;
        uint256 price1Cumulative;
    }
    
    // 代币地址 => 价格观察记录
    mapping(address => Observation[]) public observations;
    
    // 每个代币的观察历史记录上限
    uint256 public constant MAX_OBSERVATIONS = 10;
    
    // 事件：更新价格观察
    event PriceObservationUpdated(address indexed token, uint256 timestamp, uint256 price0Cumulative, uint256 price1Cumulative);

    /**
     * @dev 构造函数，设置Uniswap工厂和WETH地址
     * @param _factory Uniswap V2工厂地址
     * @param _weth WETH合约地址
     */
    constructor(address _factory, address _weth) Ownable(msg.sender) {
        require(_factory != address(0), "Invalid factory address");
        require(_weth != address(0), "Invalid WETH address");
        factory = IUniswapV2Factory(_factory);
        weth = _weth;
    }

    /**
     * @dev 更新代币的价格观察点
     * @param token 代币地址
     * @return 是否成功更新观察点
     */
    function updatePrice(address token) external returns (bool) {
        address pair = factory.getPair(token, weth);
        if (pair == address(0)) return false;
        
        // 获取价格累积数据
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 blockTimestamp) = 
            currentCumulativePrices(IUniswapV2Pair(pair));
        
        Observation memory observation = Observation({
            timestamp: blockTimestamp,
            price0Cumulative: price0Cumulative,
            price1Cumulative: price1Cumulative
        });
        
        Observation[] storage obs = observations[token];
        
        // 如果达到上限，移除最旧的观察点
        if (obs.length >= MAX_OBSERVATIONS) {
            // 移动所有元素向前一位，丢弃最旧的
            for (uint256 i = 0; i < obs.length - 1; i++) {
                obs[i] = obs[i + 1];
            }
            // 替换最后一个元素
            obs[obs.length - 1] = observation;
        } else {
            // 添加新的观察点
            obs.push(observation);
        }
        
        emit PriceObservationUpdated(token, blockTimestamp, price0Cumulative, price1Cumulative);
        return true;
    }
    
    /**
     * @dev 获取代币相对于WETH的TWAP价格
     * @param token 代币地址
     * @param period 计算TWAP的时间段（秒）
     * @return twapInWeth 代币相对于WETH的TWAP价格（1个代币值多少WETH，乘以1e18）
     * @return success 是否成功计算TWAP
     */
    function getTokenTWAP(address token, uint256 period) external view returns (uint256 twapInWeth, bool success) {
        Observation[] storage obs = observations[token];
        
        // 至少需要两个观察点
        if (obs.length < 2) return (0, false);
        
        // 寻找合适的观察点
        uint256 endIndex = obs.length - 1;
        uint256 startIndex = 0;
        
        // 从最新的开始找，直到找到足够老的观察点
        for (uint256 i = endIndex; i > 0; i--) {
            if (obs[endIndex].timestamp - obs[i - 1].timestamp >= period) {
                startIndex = i - 1;
                break;
            }
        }
        
        // 如果找不到足够的时间跨度，使用最老的观察点
        if (obs[endIndex].timestamp - obs[startIndex].timestamp < period) {
            startIndex = 0;
        }
        
        uint256 timeElapsed = obs[endIndex].timestamp - obs[startIndex].timestamp;
        if (timeElapsed == 0) return (0, false);
        
        // 获取价格累积的差值
        address pair = factory.getPair(token, weth);
        IUniswapV2Pair uniswapPair = IUniswapV2Pair(pair);
        
        // 确定token是token0还是token1
        (address token0,) = sortTokens(token, weth);
        bool isToken0 = token0 == token;
        
        // 计算价格累积差值
        uint256 priceCumulativeStart = isToken0 
            ? obs[startIndex].price0Cumulative 
            : obs[startIndex].price1Cumulative;
            
        uint256 priceCumulativeEnd = isToken0 
            ? obs[endIndex].price0Cumulative 
            : obs[endIndex].price1Cumulative;
            
        uint256 priceCumulativeDelta = priceCumulativeEnd - priceCumulativeStart;
        
        // 计算TWAP
        twapInWeth = priceCumulativeDelta / timeElapsed;
        
        // 如果token是token1，我们需要取倒数
        if (!isToken0) {
            // 避免除以0
            if (twapInWeth == 0) return (0, false);
            
            // 计算倒数，保持18位精度
            twapInWeth = (1e36 / twapInWeth);
        }
        
        return (twapInWeth, true);
    }
    
    /**
     * @dev 获取代币相对于WETH的即时价格
     * @param token 代币地址
     * @return spotPriceInWeth 代币相对于WETH的即时价格（1个代币值多少WETH，乘以1e18）
     * @return success 是否成功获取价格
     */
    function getTokenSpotPrice(address token) external view returns (uint256 spotPriceInWeth, bool success) {
        address pair = factory.getPair(token, weth);
        if (pair == address(0)) return (0, false);
        
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        
        if (token0 == token) {
            // token是token0，价格 = reserve1/reserve0
            return ((uint256(reserve1) * 1e18) / uint256(reserve0), true);
        } else {
            // token是token1，价格 = reserve0/reserve1
            return ((uint256(reserve0) * 1e18) / uint256(reserve1), true);
        }
    }
    
    /**
     * @dev 获取观察点数量
     * @param token 代币地址
     * @return 观察点数量
     */
    function getObservationsCount(address token) external view returns (uint256) {
        return observations[token].length;
    }
    
    /**
     * @dev 获取特定观察点
     * @param token 代币地址
     * @param index 观察点索引
     * @return timestamp 时间戳
     * @return price0Cumulative token0价格累积
     * @return price1Cumulative token1价格累积
     */
    function getObservation(address token, uint256 index) external view returns (
        uint256 timestamp,
        uint256 price0Cumulative,
        uint256 price1Cumulative
    ) {
        require(index < observations[token].length, "Index out of bounds");
        Observation storage obs = observations[token][index];
        return (obs.timestamp, obs.price0Cumulative, obs.price1Cumulative);
    }
    
    /**
     * @dev 检查代币是否有足够的价格历史
     * @param token 代币地址
     * @param requiredPeriod 所需时间段（秒）
     * @return 是否有足够的价格历史
     */
    function hasSufficientPriceHistory(address token, uint256 requiredPeriod) external view returns (bool) {
        Observation[] storage obs = observations[token];
        if (obs.length < 2) return false;
        
        uint256 endIndex = obs.length - 1;
        return (obs[endIndex].timestamp - obs[0].timestamp) >= requiredPeriod;
    }
    
    /**
     * @dev 删除代币的所有观察点
     * @param token 代币地址
     */
    function clearObservations(address token) external onlyOwner {
        delete observations[token];
    }
    
    /**
     * @dev 获取当前累积价格
     * @param pair Uniswap V2对合约
     * @return price0Cumulative token0价格累积
     * @return price1Cumulative token1价格累积
     * @return blockTimestamp 当前区块时间戳
     */
    function currentCumulativePrices(IUniswapV2Pair pair) internal view returns (
        uint256 price0Cumulative,
        uint256 price1Cumulative,
        uint32 blockTimestamp
    ) {
        blockTimestamp = uint32(block.timestamp);
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();

        // 如果时间已经过去，我们可以直接使用累积价格
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // 计算自上次更新以来的价格增量
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
                // 累积价格是 price * timeElapsed
                // 对于token0: reserve1/reserve0 * timeElapsed
                // 对于token1: reserve0/reserve1 * timeElapsed
                price0Cumulative += uint256(FixedPoint.fraction(reserve1, reserve0)._x) * timeElapsed;
                price1Cumulative += uint256(FixedPoint.fraction(reserve0, reserve1)._x) * timeElapsed;
            }
        }
    }
    
    /**
     * @dev 排序代币地址（与Uniswap V2一致）
     * @param tokenA 第一个代币
     * @param tokenB 第二个代币
     * @return token0 较小的地址
     * @return token1 较大的地址
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "MemeTWAPOracle: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "MemeTWAPOracle: ZERO_ADDRESS");
    }
}

/**
 * @dev 固定点数计算的辅助库（简化版）
 */
library FixedPoint {
    // 定点数，乘以2^112
    struct uq112x112 {
        uint224 _x;
    }
    
    // 返回一个分数作为UQ112x112
    function fraction(uint112 numerator, uint112 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, "FixedPoint: DIV_BY_ZERO");
        if (numerator == 0) return uq112x112(0);
        
        // 转换为Q112格式
        uint224 result = uint224((uint256(numerator) << 112) / denominator);
        return uq112x112(result);
    }
} 
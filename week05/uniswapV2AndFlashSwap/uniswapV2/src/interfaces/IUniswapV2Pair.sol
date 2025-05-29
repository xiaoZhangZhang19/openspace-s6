// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import './IUniswapV2ERC20.sol';

/**
 * @title IUniswapV2Pair
 * @dev Uniswap V2交易对合约的接口
 */
interface IUniswapV2Pair is IUniswapV2ERC20 {
    /**
     * @dev 当添加流动性时触发
     */
    event Mint(address indexed sender, uint amount0, uint amount1);
    
    /**
     * @dev 当移除流动性时触发
     */
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    
    /**
     * @dev 当交换代币时触发
     */
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    
    /**
     * @dev 当同步储备量时触发
     */
    event Sync(uint112 reserve0, uint112 reserve1);

    /**
     * @dev 返回工厂合约地址
     */
    function factory() external view returns (address);
    
    /**
     * @dev 返回代币0地址
     */
    function token0() external view returns (address);
    
    /**
     * @dev 返回代币1地址
     */
    function token1() external view returns (address);
    
    /**
     * @dev 获取当前储备量和最后更新时间戳
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    
    /**
     * @dev 返回代币0的累积价格
     */
    function price0CumulativeLast() external view returns (uint);
    
    /**
     * @dev 返回代币1的累积价格
     */
    function price1CumulativeLast() external view returns (uint);
    
    /**
     * @dev 返回最后一次流动性事件后的k值
     */
    function kLast() external view returns (uint);

    /**
     * @dev 初始化交易对，只能由工厂合约调用一次
     */
    function initialize(address, address) external;

    /**
     * @dev 添加流动性并铸造流动性代币
     */
    function mint(address to) external returns (uint liquidity);
    
    /**
     * @dev 销毁流动性代币并返还代币
     */
    function burn(address to) external returns (uint amount0, uint amount1);
    
    /**
     * @dev 交换代币
     */
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    
    /**
     * @dev 将超额代币转移出合约
     */
    function skim(address to) external;
    
    /**
     * @dev 强制使储备量与当前余额匹配
     */
    function sync() external;
} 
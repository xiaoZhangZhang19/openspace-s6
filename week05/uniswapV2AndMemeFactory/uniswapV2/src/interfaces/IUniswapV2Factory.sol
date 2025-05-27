// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IUniswapV2Factory
 * @dev Uniswap V2工厂合约的接口
 */
interface IUniswapV2Factory {
    /**
     * @dev 当创建新交易对时触发
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    /**
     * @dev 返回协议费用接收地址
     */
    function feeTo() external view returns (address);
    
    /**
     * @dev 返回有权设置协议费用接收地址的账户
     */
    function feeToSetter() external view returns (address);

    /**
     * @dev 通过代币地址对查询交易对地址
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    
    /**
     * @dev 获取所有已创建的交易对中的第i个
     */
    function allPairs(uint) external view returns (address pair);
    
    /**
     * @dev 返回已创建的交易对总数
     */
    function allPairsLength() external view returns (uint);

    /**
     * @dev 创建新的交易对
     */
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /**
     * @dev 设置协议费用接收地址
     */
    function setFeeTo(address) external;
    
    /**
     * @dev 设置有权修改协议费用接收地址的账户
     */
    function setFeeToSetter(address) external;
} 
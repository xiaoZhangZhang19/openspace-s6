// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IUniswapV2Callee
 * @dev 用于闪电贷回调的接口
 * 实现此接口的合约可以接收来自Uniswap V2交易对的回调
 */
interface IUniswapV2Callee {
    /**
     * @dev 由Uniswap V2交易对在闪电贷时调用
     * @param sender 发起交易的地址
     * @param amount0 代币0的数量
     * @param amount1 代币1的数量
     * @param data 附加数据
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
} 
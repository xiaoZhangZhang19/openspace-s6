// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "../interfaces/IUniswapV2Pair.sol";
import "./SafeMath.sol";

/**
 * @title UniswapV2Library
 * @dev 提供Uniswap V2所需的各种计算和工具函数
 * 这些函数主要被Router合约使用
 */
library UniswapV2Library {
    using SafeMath for uint;

    /**
     * @dev 对代币地址进行排序，确保操作的一致性
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return token0 较小的代币地址
     * @return token1 较大的代币地址
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @dev 计算交易对合约地址，不需要外部调用
     * 通过CREATE2计算确定性地址，提高效率
     * @param factory 工厂合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 交易对合约地址
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'a38f56ab2512906b1160e8a4974c297e041e252c4417aba03d3cce71bc39b0d1' // init code hash
            )))));
    }

    /**
     * @dev 获取交易对的储备量
     * @param factory 工厂合约地址
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return reserveA tokenA的储备量
     * @return reserveB tokenB的储备量
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev 根据输入数量和储备量计算等价的输出数量
     * @param amountA 输入的代币A数量
     * @param reserveA 代币A的储备量
     * @param reserveB 代币B的储备量
     * @return amountB 等价的代币B数量
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @dev 计算指定即将进行交换的toekn输入数量后的输出token数量，考虑了交易手续费
     * @param amountIn 输入的代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountOut 输出的代币数量
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        
        // 应用0.3%的交易手续费
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    /**
     * @dev 计算达到指定输出数量所需的输入数量，考虑了交易手续费
     * @param amountOut 期望输出的代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * @return amountIn 所需的输入代币数量
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        // add(1)是为了确保向上取整,确保计算出的amountIn（输入金额）足够完成交易。
        amountIn = (numerator / denominator).add(1);
    }

    /**
     * @dev 计算通过一系列交易对进行交易的输出数量
     * @param factory 工厂合约地址
     * @param amountIn 输入的代币数量
     * @param path 交易路径（代币地址数组）
     * @return amounts 路径上每一步的数量数组
     */
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        // 这里指的是即将进行交换的token数量
        amounts[0] = amountIn;
        
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev 计算达到指定输出数量所需的输入数量，通过一系列交易对
     * @param factory 工厂合约地址
     * @param amountOut 期望输出的代币数量
     * @param path 交易路径（代币地址数组）
     * @return amounts 路径上每一步的数量数组
     */
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
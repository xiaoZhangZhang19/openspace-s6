// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title UQ112x112
 * @dev 提供用于处理Q112.112定点数的库
 * Q112.112是一种定点数格式，其中整数部分用112位表示，小数部分也用112位表示
 * 这种格式在存储和计算价格时非常有用
 */
library UQ112x112 {
    uint224 constant Q112 = 2**112;

    /**
     * @dev 将uint112转换为Q112.112格式
     * @param y 要编码的uint112数字
     * @return z Q112.112格式的数字
     */
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // 左移112位
    }

    /**
     * @dev 将Q112.112数字除以uint112，结果仍为Q112.112格式
     * @param x Q112.112格式的被除数
     * @param y uint112格式的除数
     * @return z Q112.112格式的商
     */
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
} 
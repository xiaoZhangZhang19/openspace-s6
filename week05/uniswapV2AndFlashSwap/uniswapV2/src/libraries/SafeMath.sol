// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title SafeMath
 * @dev 提供安全的数学运算，防止溢出
 * 注意: Solidity 0.8.0+已内置溢出检查，但为了与原始代码保持一致，仍使用SafeMath
 */
library SafeMath {
    /**
     * @dev 安全加法，防止溢出
     * @param x 第一个加数
     * @param y 第二个加数
     * @return z 和
     */
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'SafeMath: addition overflow');
    }

    /**
     * @dev 安全减法，防止下溢
     * @param x 被减数
     * @param y 减数
     * @return z 差
     */
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'SafeMath: subtraction underflow');
    }

    /**
     * @dev 安全乘法，防止溢出
     * @param x 第一个因数
     * @param y 第二个因数
     * @return z 积
     */
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'SafeMath: multiplication overflow');
    }
} 
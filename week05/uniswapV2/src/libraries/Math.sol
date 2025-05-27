// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title Math
 * @dev 提供数学计算函数
 */
library Math {
    /**
     * @dev 计算数字的平方根
     * 使用巴比伦平方根算法(牛顿法的一种变体)
     * @param y 计算平方根的数字
     * @return z y的平方根
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
        // 如果y=0，则z=0
    }
    
    /**
     * @dev 返回两个数字中的最小值
     * @param x 第一个数字
     * @param y 第二个数字
     * @return 较小的数字
     */
    function min(uint x, uint y) internal pure returns (uint) {
        return x < y ? x : y;
    }
} 
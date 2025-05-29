// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IWETH
 * @dev 包装以太币(WETH)的接口
 * WETH是一个符合ERC20标准的代币，可以1:1地与ETH互换
 */
interface IWETH {
    /**
     * @dev 存入ETH并获得等量的WETH
     */
    function deposit() external payable;
    
    /**
     * @dev 取出ETH并销毁等量的WETH
     */
    function withdraw(uint) external;
    
    /**
     * @dev 转移WETH
     */
    function transfer(address to, uint value) external returns (bool);
} 
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IERC20
 * @dev ERC20代币标准接口
 */
interface IERC20 {
    /**
     * @dev 当代币所有权被授权或转移时发出的事件
     */
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev 返回代币的名称
     */
    function name() external view returns (string memory);
    
    /**
     * @dev 返回代币的符号
     */
    function symbol() external view returns (string memory);
    
    /**
     * @dev 返回代币的小数位数
     */
    function decimals() external view returns (uint8);
    
    /**
     * @dev 返回代币的总供应量
     */
    function totalSupply() external view returns (uint);
    
    /**
     * @dev 返回指定地址的代币余额
     */
    function balanceOf(address owner) external view returns (uint);
    
    /**
     * @dev 返回授权者允许被授权者使用的代币数量
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * @dev 授权spender花费调用者的代币
     */
    function approve(address spender, uint value) external returns (bool);
    
    /**
     * @dev 转移代币给指定地址
     */
    function transfer(address to, uint value) external returns (bool);
    
    /**
     * @dev 从一个地址转移代币到另一个地址
     */
    function transferFrom(address from, address to, uint value) external returns (bool);
} 
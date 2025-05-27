// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IUniswapV2ERC20
 * @dev Uniswap V2 ERC20代币的接口
 */
interface IUniswapV2ERC20 {
    /**
     * @dev 当授权变更时触发
     */
    event Approval(address indexed owner, address indexed spender, uint value);
    
    /**
     * @dev 当转账发生时触发
     */
    event Transfer(address indexed from, address indexed to, uint value);

    /**
     * @dev 返回代币名称
     */
    function name() external pure returns (string memory);
    
    /**
     * @dev 返回代币符号
     */
    function symbol() external pure returns (string memory);
    
    /**
     * @dev 返回代币小数位数
     */
    function decimals() external pure returns (uint8);
    
    /**
     * @dev 返回代币总供应量
     */
    function totalSupply() external view returns (uint);
    
    /**
     * @dev 返回指定地址的代币余额
     */
    function balanceOf(address owner) external view returns (uint);
    
    /**
     * @dev 返回owner授权给spender的代币数量
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * @dev 返回EIP-712域分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
    /**
     * @dev 返回permit函数的类型哈希
     */
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    
    /**
     * @dev 返回指定地址的nonce值
     */
    function nonces(address owner) external view returns (uint);

    /**
     * @dev 授权spender花费调用者的代币
     */
    function approve(address spender, uint value) external returns (bool);
    
    /**
     * @dev 将调用者的代币转移到指定地址
     */
    function transfer(address to, uint value) external returns (bool);
    
    /**
     * @dev 将一个地址的代币转移到另一个地址（需要授权）
     */
    function transferFrom(address from, address to, uint value) external returns (bool);

    /**
     * @dev 通过签名进行授权
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
} 
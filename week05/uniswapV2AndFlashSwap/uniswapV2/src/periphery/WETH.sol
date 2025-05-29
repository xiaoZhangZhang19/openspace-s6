// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IWETH.sol";

/**
 * @title WETH
 * @dev 包装以太币(WETH)合约
 * 允许用户将ETH转换为符合ERC20标准的代币
 */
contract WETH is IWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    // 用户余额映射
    mapping(address => uint) public balanceOf;
    // 授权映射
    mapping(address => mapping(address => uint)) public allowance;

    // 转账事件
    event Transfer(address indexed from, address indexed to, uint value);
    // 授权事件
    event Approval(address indexed owner, address indexed spender, uint value);
    // 存款事件
    event Deposit(address indexed dst, uint wad);
    // 取款事件
    event Withdrawal(address indexed src, uint wad);

    /**
     * @dev 接收ETH并铸造等量的WETH
     */
    receive() external payable {
        deposit();
    }

    /**
     * @dev 存入ETH并铸造等量的WETH
     */
    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 取出ETH并销毁等量的WETH
     * @param wad 取款金额
     */
    function withdraw(uint wad) public {
        require(balanceOf[msg.sender] >= wad, "WETH: insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    /**
     * @dev 返回代币总供应量（等于合约ETH余额）
     */
    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    /**
     * @dev 授权spender花费调用者的代币
     * @param spender 被授权者地址
     * @param value 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转移WETH
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "WETH: insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 授权转账函数，将一个地址的代币转移到另一个地址（需要授权）
     * @param from 发送者地址
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) public returns (bool) {
        require(balanceOf[from] >= value, "WETH: insufficient balance");
        
        if (allowance[from][msg.sender] != type(uint).max) {
            require(allowance[from][msg.sender] >= value, "WETH: insufficient allowance");
            allowance[from][msg.sender] -= value;
        }
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}
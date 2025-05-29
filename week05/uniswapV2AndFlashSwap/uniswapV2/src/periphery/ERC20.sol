// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../interfaces/IERC20.sol";

/**
 * @title ERC20
 * @dev 实现ERC20代币标准的合约
 * 用于测试Uniswap V2交易功能
 */
contract ERC20 is IERC20 {
    // 代币名称
    string public name;
    // 代币符号
    string public symbol;
    // 代币小数位数
    uint8 public constant decimals = 18;
    // 代币总供应量
    uint public totalSupply;
    
    // 用户余额映射
    mapping(address => uint) public balanceOf;
    // 授权映射
    mapping(address => mapping(address => uint)) public allowance;

    /**
     * @dev 构造函数
     * @param _name 代币名称
     * @param _symbol 代币符号
     * @param _initialSupply 初始代币供应量或小数位数（在不同脚本中有不同用法）
     */
    constructor(string memory _name, string memory _symbol, uint _initialSupply) {
        name = _name;
        symbol = _symbol;
        
        // 如果_initialSupply较小（如18），则认为它是小数位数
        // 否则认为它是初始供应量并进行铸造
        if (_initialSupply > 100) {
        _mint(msg.sender, _initialSupply);
        }
    }

    /**
     * @dev 内部铸造函数，创建新代币并分配给指定地址
     * @param to 接收代币的地址
     * @param value 铸造的代币数量
     */
    function _mint(address to, uint value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 外部铸造函数，允许合约所有者创建新代币
     * @param to 接收代币的地址
     * @param value 铸造的代币数量
     */
    function mint(address to, uint value) external virtual {
        _mint(to, value);
    }

    /**
     * @dev 内部销毁函数，从指定地址销毁代币
     * @param from 销毁代币的地址
     * @param value 销毁的代币数量
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 销毁函数，允许用户销毁自己的代币
     * @param value 销毁的代币数量
     */
    function burn(uint value) external {
        _burn(msg.sender, value);
    }

    /**
     * @dev 授权spender花费调用者的代币
     * @param spender 被授权者地址
     * @param value 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转移代币
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool) {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 代表他人转移代币，需要授权
     * @param from 发送者地址
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] -= value;
        }
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
} 
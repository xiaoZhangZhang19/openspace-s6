// SPDX-License-Identifier: MIT 
// 指定Solidity编译器版本为0.8.29或更高
pragma solidity ^0.8.29;

// 导入Bank合约
import "../Bank/Bank.sol";

/**
 * @title GovernedBank
 * @dev 继承自Bank合约，但withdraw方法只能被DAO治理合约调用
 */
// 定义GovernedBank合约，继承自Bank合约
contract GovernedBank is Bank {
    /**
     * @dev 构造函数，设置初始管理员为部署合约的地址
     */
    // 构造函数，调用父合约Bank的构造函数
    constructor() Bank() {}
    
    /**
     * @dev 将管理员设置为DAO治理合约
     * @param newOwner 新的管理员地址(DAO治理合约)
     */
    // 定义外部函数，只有当前所有者可以调用
    function setDAOAsOwner(address newOwner) external onlyOwner {
        // 调用内部函数转移所有权
        _transferOwnership(newOwner);
    }
    
    /**
     * @dev 重写withdraw方法，确保只有管理员(DAO治理合约)可以调用
     */
    // 重写父合约的withdraw函数，只有所有者可以调用
    function withdraw(uint256 amount) public override onlyOwner {
        // 调用父合约的withdraw函数
        super.withdraw(amount);
    }

    /**
     * @dev 添加一个新的withdraw方法，接收recipient参数，将资金直接发送到指定地址
     * @param recipient 资金接收者地址
     * @param amount 提取金额
     */
    function withdrawTo(address recipient, uint256 amount) public onlyOwner {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must > 0");
        (bool success,) = recipient.call{value: amount}("");
        require(success, "withdraw failed!");
        emit withdrawETH(recipient, address(this).balance);
    }
}
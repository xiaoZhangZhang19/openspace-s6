// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../Bank/Bank.sol";

/**
 * @title GovernedBank
 * @dev 继承自Bank合约，但withdraw方法只能被DAO治理合约调用
 */
contract GovernedBank is Bank {
    /**
     * @dev 构造函数，设置初始管理员为部署合约的地址
     */
    constructor() Bank() {}
    
    /**
     * @dev 将管理员设置为DAO治理合约
     * @param newOwner 新的管理员地址(DAO治理合约)
     */
    function setDAOAsOwner(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }
    
    /**
     * @dev 重写withdraw方法，确保只有管理员(DAO治理合约)可以调用
     */
    function withdraw() public override onlyOwner {
        super.withdraw();
    }
} 
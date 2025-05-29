// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ERC20.sol";

/**
 * @title MyToken
 * @dev 自定义ERC20代币，用于Uniswap V2套利测试
 */
contract MyToken is ERC20 {
    /**
     * @dev 构造函数，创建MyToken代币
     * @param _initialSupply 初始供应量
     */
    constructor(uint256 _initialSupply) ERC20("MyToken", "MTK", _initialSupply) {
        // 构造函数中的逻辑已在父合约中处理
    }
    
    /**
     * @dev 允许任何人铸造代币（仅用于测试）
     * @param to 接收代币的地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external override {
        _mint(to, amount);
    }
} 
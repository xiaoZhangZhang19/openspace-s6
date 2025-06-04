// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.29;

// 导入OpenZeppelin的ERC20合约
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 导入ERC20Permit扩展
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
// 导入ERC20Votes扩展
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
// 导入Nonces工具
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovernanceToken
 * @dev 实现一个具有投票功能的ERC20代币
 */
// 定义GovernanceToken合约，继承多个合约
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    // 构造函数，初始化ERC20和ERC20Permit
    constructor() ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {
        // 初始供应量 1,000,000 代币
        // 铸造初始代币给部署者
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }

    // 下面的函数是由Solidity要求的重写
    // 重写_update函数
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        // 调用父合约的_update函数
        super._update(from, to, amount);
    }

    // 重写nonces函数
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        // 调用父合约的nonces函数
        return super.nonces(owner);
    }
}
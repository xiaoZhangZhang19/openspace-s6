// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovernanceToken
 * @dev 实现一个具有投票功能的ERC20代币
 */
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {
        // 初始供应量 1,000,000 代币
        _mint(msg.sender, 1_000_000 * 10**decimals());
    }

    // 下面的函数是由Solidity要求的重写
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
} 
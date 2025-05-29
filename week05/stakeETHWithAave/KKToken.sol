// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title KK Token 
 */
interface IToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title KK Token 实现
 */
contract KKToken is ERC20, Ownable, IToken {
    // 授权铸币者
    address public minter;
    
    // 铸币者事件
    event MinterSet(address indexed previousMinter, address indexed newMinter);
    
    /**
     * @dev 仅授权铸币者可调用的修饰符
     */
    modifier onlyMinter() {
        require(msg.sender == minter || msg.sender == owner(), "KKToken: caller is not the minter or owner");
        _;
    }
    
    constructor() ERC20("KK Token", "KK") Ownable(msg.sender) {
        // 初始铸币者为合约创建者
        minter = msg.sender;
    }

    /**
     * @dev 设置铸币者
     * @param _minter 新的铸币者地址
     */
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "KKToken: new minter is the zero address");
        address oldMinter = minter;
        minter = _minter;
        emit MinterSet(oldMinter, _minter);
    }

    /**
     * @dev 铸造 KK Token，只有 minter 或 owner 可以调用
     * @param to 接收者地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external override onlyMinter {
        _mint(to, amount);
    }
} 
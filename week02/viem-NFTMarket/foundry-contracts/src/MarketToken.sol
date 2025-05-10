// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ERC20TokenReceiver {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract MarketToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Market Token", "MKT") {
        _mint(msg.sender, initialSupply);
    }
    
    // 扩展的transfer函数，添加data参数
    function transferWithData(address to, uint256 amount, bytes calldata data) public returns (bool) {
        _transfer(msg.sender, to, amount);
        
        // 如果接收者是合约，调用tokensReceived
        if (isContract(to)) {
            ERC20TokenReceiver receiver = ERC20TokenReceiver(to);
            require(
                receiver.tokensReceived(msg.sender, msg.sender, to, amount, data),
                "ERC20: transfer to non ERC20TokenReceiver implementer"
            );
        }
        
        return true;
    }
    
    // 检查地址是否为合约
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
} 

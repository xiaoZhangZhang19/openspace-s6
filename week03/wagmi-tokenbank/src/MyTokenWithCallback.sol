// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface TokenRecipient {
    function tokensReceived(address sender, uint amount) external returns (bool);
}

contract MyTokenWithCallback is ERC20Permit{

    event TransferWithCallback(address indexed from, address indexed to, uint256 value);

    constructor(string memory name_, string memory symbol_, uint256 initialSupply_) 
    ERC20(name_, symbol_) 
    ERC20Permit(name_) {
        _mint(msg.sender, initialSupply_);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function isContract(address _addr) public view returns (bool) {
        if (_addr.code.length > 0) {
            return true;
        }else {
            return false;
        }
    }

    function transferWithCallback(address recipient, uint256 amount) external returns (bool) {

        emit TransferWithCallback(msg.sender, recipient, amount);
        if (isContract(recipient)) {
            bool rv = TokenRecipient(recipient).tokensReceived(msg.sender, amount);
            require(rv, "No tokensReceived");
        }
        

        _transfer(msg.sender, recipient, amount);
        
        return true;
    }
}

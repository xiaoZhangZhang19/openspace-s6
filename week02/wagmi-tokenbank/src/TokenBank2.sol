// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./TokenBank.sol";

contract TokenBank2 is TokenBank{

    constructor(address _tokenAddress) TokenBank(_tokenAddress){
    }

    function tokensReceived(address _sender, uint256 _amount) public returns (bool){
        require(_amount > 0,"must > zero amount");
        // 调用此方法的用户必须是token合约，否则会出现安全问题
        require(msg.sender == tokenAddress, "can't receive!");
        tokenBalances[_sender] += _amount;
        return true;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./TokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract TokenBank2 is TokenBank{

    constructor(address _tokenAddress) TokenBank(_tokenAddress){
    }

    event depositByTokenReceivedLog(address _addr, uint256 balance);

    function tokensReceived(address _sender, uint256 _amount) public returns (bool){
        require(_amount > 0,"must > zero amount");
        // 调用此方法的用户必须是token合约，否则会出现安全问题
        require(msg.sender == tokenAddress, "can't receive!");
        tokenBalances[_sender] += _amount;
        emit depositByTokenReceivedLog(_sender, _amount);
        return true;
    }

    /**
     * @notice 通过permit离线签名授权进行存款
     * @param amount 存款金额
     * @param deadline 签名的截止时间
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 先执行permit授权
        IERC20Permit(tokenAddress).permit(
            msg.sender,      // owner
            address(this),   // spender
            amount,         // value
            deadline,      // deadline
            v, r, s        // 签名
        );
        
        // 然后执行存款
        require(amount > 0, "must > zero amount");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "transfer failed!");
        tokenBalances[msg.sender] += amount;
        emit depositLog(msg.sender, amount);
    }
}

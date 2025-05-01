// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// 编写一个 Bank 合约，实现功能：
// 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 在 Bank 合约记录每个地址的存款金额
// 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 用数组记录存款金额的前 3 名用户

event withdrawETH(address, uint);

contract Bank {
    address public owner;
    mapping (address => uint256) public balances;
    mapping (address => bool) public isDeposit;
    address[] public depositors;
    
    // 直接存储前三名存款人
    address[3] public topDepositors;
    
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(msg.sender==owner,"Caller is not the owner");
        _;
    }

    // 更新前三名存款人
    function _updateTopDepositors(address depositor) private {
        uint256 amount = balances[depositor];
        
        // 检查是否需要更新前三名
        if (topDepositors[0] == address(0) || amount > balances[topDepositors[0]]) {
            // 新的第一名，其他依次后移
            topDepositors[2] = topDepositors[1];
            topDepositors[1] = topDepositors[0];
            topDepositors[0] = depositor;
        } else if (topDepositors[1] == address(0) || amount > balances[topDepositors[1]]) {
            // 新的第二名，第二名后移
            topDepositors[2] = topDepositors[1];
            topDepositors[1] = depositor;
        } else if (topDepositors[2] == address(0) || amount > balances[topDepositors[2]]) {
            // 新的第三名
            topDepositors[2] = depositor;
        }
    }

    receive() external payable {
        require(msg.value > 0, "Amount must > 0");

        if (!isDeposit[msg.sender]) {
            //防止数组重复写入
            isDeposit[msg.sender] = true;
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        
        // 每次存款后更新前三名
        _updateTopDepositors(msg.sender);
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Not enough funds!");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "withdraw failed!");
        emit withdrawETH(msg.sender, amount);
    }

    function getTop3Depositor() public view returns (address[3] memory) {
        // 直接返回储存的前三名，不需要遍历
        return topDepositors;
    }
}
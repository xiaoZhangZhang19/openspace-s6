// SPDX-License-Identifier: SEE LICENSE IN LICENSE 
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract BankWithAutomation is Ownable, AutomationCompatibleInterface {

    mapping(address => uint256) public balances;
    
    // 触发自动化的阈值 (0.01 ETH)
    uint256 public constant AUTOMATION_THRESHOLD = 0.01 ether;
    
    // 事件
    event AutomationTriggered(uint256 amount, address owner);
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);

    constructor() Ownable(msg.sender) {}

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev ChainLink Automation 检查函数
     * 当合约余额超过 0.01 ETH 时返回 true
     */
    function checkUpkeep(bytes calldata /* checkData */) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        uint256 balance = address(this).balance;
        upkeepNeeded = balance >= AUTOMATION_THRESHOLD;
        
        if (upkeepNeeded) {
            // 预先计算转账金额，避免在 performUpkeep 中重复计算
            uint256 transferAmount = balance / 2;
            performData = abi.encode(transferAmount);
        } else {
            performData = "";
        }
        
        return (upkeepNeeded, performData);
    }

    /**
     * @dev ChainLink Automation 执行函数
     * 将合约余额的一半转移给 owner
     */
    function performUpkeep(bytes calldata performData) external override {
        // 再次检查条件，确保安全
        require(address(this).balance >= AUTOMATION_THRESHOLD, "Balance below threshold");
        
        // 从 performData 中解码预计算的转账金额
        uint256 transferAmount;
        if (performData.length > 0) {
            transferAmount = abi.decode(performData, (uint256));
            // 验证数据是否仍然有效（防止状态变化导致的不一致）
            uint256 currentBalance = address(this).balance;
            uint256 expectedAmount = currentBalance / 2;
            if (transferAmount > expectedAmount) {
                transferAmount = expectedAmount; // 使用当前计算的安全值
            }
        } else {
            // 如果没有传递数据，重新计算
            transferAmount = address(this).balance / 2;
        }
        
        // 转移资金给 owner
        payable(owner()).transfer(transferAmount);
        
        emit AutomationTriggered(transferAmount, owner());
    }
}
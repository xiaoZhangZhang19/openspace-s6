// SPDX-License-Identifier: SEE LICENSE IN LICENSE 
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract BankWithAutomation is Ownable, ReentrancyGuard, AutomationCompatibleInterface {

    mapping(address => uint256) public balances;
    
    // 触发自动化的阈值 (0.01 ETH)
    uint256 public constant AUTOMATION_THRESHOLD = 0.01 ether;
    
    // 事件
    event AutomationTriggered(uint256 amount, address owner);
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // 接收 ETH 的函数
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Insufficient balance");
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev 计算转账金额的内部函数（避免重复计算）
     */
    function _calculateTransferAmount(uint256 currentBalance) internal pure returns (uint256) {
        return currentBalance / 2;
    }
    
    /**
     * @dev ChainLink Automation 检查函数
     * 当合约余额超过 0.01 ETH 时返回 true
     * （用于 Custom Logic 模式）
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
            // 传递余额和时间戳，让 performUpkeep 根据当时的实际余额计算
            performData = abi.encode(balance, block.timestamp);
        } else {
            performData = "";
        }
        
        return (upkeepNeeded, performData);
    }

    /**
     * @dev ChainLink Automation 执行函数
     * 用于 Custom Logic 模式
     */
    function performUpkeep(bytes calldata performData) external override nonReentrant {
        uint256 currentBalance = address(this).balance;
        
        // 再次检查条件，确保安全
        require(currentBalance >= AUTOMATION_THRESHOLD, "Balance below threshold");
        
        uint256 transferAmount;
        
        if (performData.length > 0) {
            // Custom Logic 模式
            (uint256 checkBalance, uint256 checkTimestamp) = abi.decode(performData, (uint256, uint256));
            
            // 验证数据的时效性和合理性
            // 如果余额变化超过 20% 或时间过去太久，重新计算
            uint256 balanceChangeThreshold = checkBalance / 5; // 20%
            if (currentBalance > checkBalance + balanceChangeThreshold || 
                currentBalance < checkBalance - balanceChangeThreshold ||
                block.timestamp > checkTimestamp + 300) { // 5分钟超时
                
                // 数据过时，重新计算
                transferAmount = _calculateTransferAmount(currentBalance);
            } else {
                // 数据仍然有效，使用当前余额计算
                transferAmount = _calculateTransferAmount(currentBalance);
            }
        } else {
            // 空数据，直接使用当前余额计算
            transferAmount = _calculateTransferAmount(currentBalance);
        }
        
        // 最终安全检查：确保转账金额不超过当前余额
        require(transferAmount <= currentBalance, "Transfer amount exceeds balance");
        require(transferAmount > 0, "Transfer amount must be greater than 0");
        
        // 使用更安全的转账方法
        (bool success, ) = payable(owner()).call{value: transferAmount}("");
        require(success, "Transfer to owner failed");
        
        emit AutomationTriggered(transferAmount, owner());
    }

    /**
     * @dev 获取当前如果执行自动化会转账多少金额（用于前端展示）
     */
    function getExpectedTransferAmount() external view returns (uint256) {
        uint256 balance = address(this).balance;
        if (balance < AUTOMATION_THRESHOLD) {
            return 0;
        }
        return _calculateTransferAmount(balance);
    }
}
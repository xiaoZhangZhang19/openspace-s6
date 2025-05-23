// SPDX-License-Identifier: SEE LICENSE IN LICENSE 
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// 🟢 Log Trigger 需要使用 ILogAutomation 接口
struct Log {
    uint256 index;
    uint256 timestamp;
    bytes32 txHash;
    uint256 blockNumber;
    bytes32 blockHash;
    address source;
    bytes32[] topics;
    bytes data;
}

interface ILogAutomation {
    function checkLog(
        Log calldata log,
        bytes memory checkData
    ) external returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

contract BankWithAutomationLogTrigger is Ownable, ReentrancyGuard, ILogAutomation {

    mapping(address => uint256) public balances;
    
    // 触发自动化的阈值 (0.01 ETH)
    uint256 public constant AUTOMATION_THRESHOLD = 0.01 ether;
    
    // 事件
    event AutomationTriggered(uint256 amount, address owner);
    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    
    // 🔥 Log Trigger 事件
    event AutoTransferRequested(
        uint256 indexed requestId,
        uint256 contractBalance,
        uint256 transferAmount,
        uint256 timestamp
    );

    // 请求计数器
    uint256 private requestCounter;

    constructor() Ownable(msg.sender) {}

    // 接收 ETH 的函数
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        
        // 检查是否需要触发自动转账
        _checkAndTriggerAutoTransfer();
    }

    function deposit() public payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
        
        // 检查是否需要触发自动转账
        _checkAndTriggerAutoTransfer();
    }

    function withdraw(uint256 amount) public onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Insufficient balance");
        
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev 检查并触发自动转账请求（用于 Log Trigger）
     */
    function _checkAndTriggerAutoTransfer() internal {
        uint256 balance = address(this).balance;
        if (balance >= AUTOMATION_THRESHOLD) {
            uint256 transferAmount = balance / 2;
            uint256 requestId = ++requestCounter;
            
            // 发出事件，ChainLink Log Trigger 会监听这个事件
            emit AutoTransferRequested(
                requestId,
                balance,
                transferAmount,
                block.timestamp
            );
        }
    }
    
    /**
     * @dev 手动触发自动转账请求
     */
    function requestAutoTransfer() external {
        _checkAndTriggerAutoTransfer();
    }

    /**
     * @dev 🟢 Log Trigger 必需：checkLog 函数
     * 当监听到 AutoTransferRequested 事件时被调用
     */
    function checkLog(
        Log calldata log,
        bytes memory /* checkData */
    ) external pure override returns (bool upkeepNeeded, bytes memory performData) {
        // 总是返回 true，表示需要执行 performUpkeep
        upkeepNeeded = true;
        
        // 从 log 中解析数据
        // log.data 包含事件的非 indexed 参数
        (uint256 contractBalance, uint256 transferAmount, uint256 timestamp) = 
            abi.decode(log.data, (uint256, uint256, uint256));
        
        // 将解析的数据传递给 performUpkeep
        performData = abi.encode(contractBalance, transferAmount, timestamp);
    }

    /**
     * @dev 🟢 Log Trigger 必需：performUpkeep 函数
     * 执行实际的转账操作
     */
    function performUpkeep(bytes calldata /* performData */) external override nonReentrant {
        // 对于这个简化版本，我们直接使用当前余额，忽略 log 数据
        // 因为在实际执行时，当前余额是最准确的
        
        uint256 currentBalance = address(this).balance;
        
        // 安全检查
        require(currentBalance >= AUTOMATION_THRESHOLD, "Balance below threshold");
        
        // 计算实际转账金额（使用当前余额）
        uint256 actualTransferAmount = currentBalance / 2;
        
        // 最终安全检查
        require(actualTransferAmount <= currentBalance, "Transfer amount exceeds balance");
        require(actualTransferAmount > 0, "Transfer amount must be greater than 0");
        
        // 执行转账
        (bool success, ) = payable(owner()).call{value: actualTransferAmount}("");
        require(success, "Transfer to owner failed");
        
        emit AutomationTriggered(actualTransferAmount, owner());
    }
    
    /**
     * @dev 获取当前请求计数器
     */
    function getCurrentRequestId() external view returns (uint256) {
        return requestCounter;
    }

    /**
     * @dev 获取预期转账金额
     */
    function getExpectedTransferAmount() external view returns (uint256) {
        uint256 balance = address(this).balance;
        if (balance < AUTOMATION_THRESHOLD) {
            return 0;
        }
        return balance / 2;
    }
} 
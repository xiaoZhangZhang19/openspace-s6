// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vesting
 * @dev 线性释放合约，支持悬崖期和线性释放期
 * 
 * 参数说明：
 * - beneficiary: 受益人地址
 * - token: 锁定的 ERC20 代币地址
 * - cliff: 12 个月悬崖期
 * - vesting: 24 个月线性释放期
 * - totalAmount: 总释放数量（100万代币）
 */
contract Vesting is ReentrancyGuard {
    // 受益人地址
    address public immutable beneficiary;
    
    // 锁定的 ERC20 代币
    IERC20 public immutable token;
    
    // 悬崖期持续时间（秒）
    uint256 public immutable cliffDuration;
    
    // 线性释放期持续时间（秒）
    uint256 public immutable vestingDuration;
    
    // 合约部署时间（开始计算时间）
    uint256 public immutable startTime;
    
    // 总释放数量
    uint256 public immutable totalAmount;
    
    // 已释放数量
    uint256 public released;
    
    // 事件
    event TokensReleased(uint256 amount);
    
    /**
     * @dev 构造函数
     * @param _beneficiary 受益人地址
     * @param _token ERC20 代币地址
     * @param _cliffDuration 悬崖期持续时间（秒）
     * @param _vestingDuration 线性释放期持续时间（秒）
     * @param _totalAmount 总释放数量
     */
    constructor(
        address _beneficiary,
        address _token,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _totalAmount
    ) {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_token != address(0), "Token cannot be zero address");
        require(_cliffDuration > 0, "Cliff duration must be greater than 0");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");
        require(_totalAmount > 0, "Total amount must be greater than 0");
        
        beneficiary = _beneficiary;
        token = IERC20(_token);
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        startTime = block.timestamp;
        totalAmount = _totalAmount;
    }
    
    /**
     * @dev 计算当前可释放的代币数量
     * @return 可释放的代币数量
     */
    function releasable() public view returns (uint256) {
        // 如果还在悬崖期内，返回 0
        if (block.timestamp < startTime + cliffDuration) {
            return 0;
        }
        
        // 计算从悬崖期结束后经过的时间
        uint256 elapsedSinceCliff = block.timestamp - (startTime + cliffDuration);
        
        // 如果超过了线性释放期，返回剩余的所有代币
        if (elapsedSinceCliff >= vestingDuration) {
            return totalAmount - released;
        }
        
        // 线性释放计算：根据经过的时间比例计算已授权的代币数量
        uint256 vestedAmount = (totalAmount * elapsedSinceCliff) / vestingDuration;
        
        // 返回已授权但未释放的代币数量
        return vestedAmount - released;
    }
    
    /**
     * @dev 释放当前可用的代币给受益人
     */
    function release() external nonReentrant {
        uint256 unreleased = releasable();
        require(unreleased > 0, "No tokens to release");
        
        // 更新已释放数量
        released += unreleased;
        
        // 转移代币给受益人
        require(token.transfer(beneficiary, unreleased), "Token transfer failed");
        
        emit TokensReleased(unreleased);
    }
    
    /**
     * @dev 获取合约信息
     * @return _beneficiary 受益人地址
     * @return _token 代币地址
     * @return _startTime 开始时间
     * @return _cliffDuration 悬崖期持续时间
     * @return _vestingDuration 线性释放期持续时间
     * @return _totalAmount 总释放数量
     * @return _released 已释放数量
     */
    function getVestingInfo() external view returns (
        address _beneficiary,
        address _token,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _totalAmount,
        uint256 _released
    ) {
        return (
            beneficiary,
            address(token),
            startTime,
            cliffDuration,
            vestingDuration,
            totalAmount,
            released
        );
    }
} 
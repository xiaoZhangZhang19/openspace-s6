// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title BankTimelockController
 * @dev 实现时间锁控制器，用于延迟执行提案
 */
contract BankTimelockController is TimelockController {
    /**
     * @dev 构造函数
     * @param minDelay 最小延迟时间（秒）
     * @param proposers 可以提出延迟操作的地址数组
     * @param executors 可以执行延迟操作的地址数组
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
} 
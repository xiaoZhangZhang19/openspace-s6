// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/Bank/BankWithAutomation.sol";

contract BankWithAutomationTest is Test {
    BankWithAutomation public bank;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this); // 测试合约作为owner
        user1 = address(0x1);
        user2 = address(0x2);
        
        bank = new BankWithAutomation();
        
        // 给用户一些ETH进行测试
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testDeposit() public {
        vm.startPrank(user1);
        
        uint256 depositAmount = 0.005 ether;
        bank.deposit{value: depositAmount}();
        
        assertEq(bank.balances(user1), depositAmount);
        assertEq(address(bank).balance, depositAmount); // 直接查询合约余额
        
        vm.stopPrank();
    }

    function testReceive() public {
        vm.startPrank(user1);
        
        uint256 depositAmount = 0.005 ether;
        // 直接向合约发送 ETH，测试 receive 函数
        (bool success, ) = address(bank).call{value: depositAmount}("");
        assertTrue(success);
        
        assertEq(bank.balances(user1), depositAmount);
        assertEq(address(bank).balance, depositAmount);
        
        vm.stopPrank();
    }

    function testAutomationThreshold() public {
        // 初始状态不应该触发自动化
        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.005 ether}();
        
        (upkeepNeeded,) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
        
        // 存入超过阈值的金额
        vm.prank(user2);
        bank.deposit{value: 0.008 ether}(); // 总计 0.013 ether > 0.01 ether
        
        (upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeep() public {
        // 先存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.015 ether}();
        
        uint256 contractBalanceBefore = address(bank).balance;
        uint256 ownerBalanceBefore = address(this).balance;
        
        // 验证可以执行自动化
        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 执行自动化
        bank.performUpkeep("");
        
        uint256 contractBalanceAfter = address(bank).balance;
        uint256 ownerBalanceAfter = address(this).balance;
        
        // 验证一半资金被转移给owner
        uint256 expectedTransfer = contractBalanceBefore / 2;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedTransfer);
        assertEq(contractBalanceAfter, contractBalanceBefore - expectedTransfer);
    }

    function testPerformUpkeepFailsWhenBelowThreshold() public {
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.005 ether}();
        
        // 尝试执行自动化应该失败
        vm.expectRevert("Balance below threshold");
        bank.performUpkeep("");
    }

    function testMultipleDepositsAndAutomation() public {
        // 多次存款
        vm.prank(user1);
        bank.deposit{value: 0.006 ether}();
        
        vm.prank(user2);
        bank.deposit{value: 0.007 ether}(); // 总计 0.013 ether
        
        uint256 initialBalance = address(bank).balance;
        assertEq(initialBalance, 0.013 ether);
        
        // 执行第一次自动化
        bank.performUpkeep("");
        
        uint256 afterFirstAutomation = address(bank).balance;
        assertEq(afterFirstAutomation, initialBalance / 2); // 0.0065 ether
        
        // 再存入一些，触发第二次自动化
        vm.prank(user1);
        bank.deposit{value: 0.005 ether}(); // 总计 0.0115 ether
        
        (bool upkeepNeeded,) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        bank.performUpkeep("");
        
        uint256 finalBalance = address(bank).balance;
        assertEq(finalBalance, 0.0115 ether / 2); // 约 0.00575 ether
    }

    function testWithdrawByOwner() public {
        // 存入一些资金
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        uint256 withdrawAmount = 0.01 ether;
        uint256 ownerBalanceBefore = address(this).balance;
        
        bank.withdraw(withdrawAmount);
        
        uint256 ownerBalanceAfter = address(this).balance;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, withdrawAmount);
    }

    function testPerformDataEncoding() public {
        // 存入超过阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.015 ether}();
        
        // 检查 checkUpkeep 返回的 performData
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertTrue(performData.length > 0);
        
        // 解码 performData 格式 (balance, timestamp)
        (uint256 encodedBalance, uint256 encodedTimestamp) = abi.decode(performData, (uint256, uint256));
        assertEq(encodedBalance, 0.015 ether);
        assertEq(encodedTimestamp, block.timestamp);
        
        // 使用返回的 performData 执行自动化
        uint256 ownerBalanceBefore = address(this).balance;
        bank.performUpkeep(performData);
        uint256 ownerBalanceAfter = address(this).balance;
        
        // 现在转账金额是基于执行时的实际余额计算的
        uint256 expectedTransfer = 0.015 ether / 2;
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedTransfer);
    }

    function testPerformDataWhenBelowThreshold() public {
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.005 ether}();
        
        // 检查 checkUpkeep 返回的 performData
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(performData.length, 0); // 应该返回空数据
    }

    function testBothPerformUpkeepPaths() public {
        // 测试1: 验证 performData 路径（使用余额和时间戳数据）
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        // 获取 performData（这时余额是 0.02 ETH）
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertTrue(performData.length > 0);
        
        // 解码新的数据格式
        (uint256 checkBalance, uint256 checkTimestamp) = abi.decode(performData, (uint256, uint256));
        assertEq(checkBalance, 0.02 ether);
        assertEq(checkTimestamp, block.timestamp);
        
        uint256 ownerBalance1 = address(this).balance;
        bank.performUpkeep(performData); // 使用 performData
        uint256 transferred1 = address(this).balance - ownerBalance1;
        assertEq(transferred1, 0.01 ether); // 0.02 ETH / 2
        
        // 测试2: 验证空字符串路径（重新计算）
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}(); // 现在余额变成 0.03 ETH (0.01 + 0.02)
        
        uint256 currentBalance = address(bank).balance;
        uint256 expectedNewTransfer = currentBalance / 2; // 应该是 0.015 ETH
        
        uint256 ownerBalance2 = address(this).balance;
        bank.performUpkeep(""); // 空字符串，重新计算当前余额
        uint256 transferred2 = address(this).balance - ownerBalance2;
        
        assertEq(transferred2, expectedNewTransfer); // 应该是 0.015 ETH
        assertTrue(transferred2 > transferred1); // 第二次转移更多，因为余额增加了
        
        // 验证两种方式都能正常工作，但计算基准不同
        console.log("First transfer (using performData):", transferred1);
        console.log("Second transfer (recalculated):", transferred2);
    }

    // 测试数据时效性验证
    function testPerformDataTimeValidation() public {
        // 存入资金
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        // 获取 performData
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 模拟时间流逝（超过5分钟阈值）
        vm.warp(block.timestamp + 400); // 6分40秒后
        
        uint256 ownerBalanceBefore = address(this).balance;
        
        // 即使 performData 过时，依然应该正常执行（重新计算）
        bank.performUpkeep(performData);
        
        uint256 ownerBalanceAfter = address(this).balance;
        uint256 transferred = ownerBalanceAfter - ownerBalanceBefore;
        
        // 应该基于当前余额重新计算
        assertEq(transferred, 0.01 ether);
    }

    // 测试余额变化验证
    function testPerformDataBalanceValidation() public {
        // 存入资金
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        // 获取 performData
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 模拟余额大幅变化（用户又存入了很多钱）
        vm.prank(user2);
        bank.deposit{value: 0.05 ether}(); // 余额从 0.02 变成 0.07，变化超过20%
        
        uint256 ownerBalanceBefore = address(this).balance;
        uint256 currentBalance = address(bank).balance; // 0.07 ether
        
        // 应该基于当前余额重新计算，而不是使用过时的数据
        bank.performUpkeep(performData);
        
        uint256 ownerBalanceAfter = address(this).balance;
        uint256 transferred = ownerBalanceAfter - ownerBalanceBefore;
        
        // 应该是当前余额的一半
        assertEq(transferred, currentBalance / 2); // 0.035 ether
    }

    // 测试 getExpectedTransferAmount 函数
    function testGetExpectedTransferAmount() public {
        // 初始状态：余额为0，预期转账为0
        uint256 expected = bank.getExpectedTransferAmount();
        assertEq(expected, 0);
        
        // 存入少于阈值的金额
        vm.prank(user1);
        bank.deposit{value: 0.005 ether}();
        
        expected = bank.getExpectedTransferAmount();
        assertEq(expected, 0); // 仍然为0，因为低于阈值
        
        // 存入超过阈值的金额
        vm.prank(user2);
        bank.deposit{value: 0.01 ether}(); // 总共 0.015 ether
        
        expected = bank.getExpectedTransferAmount();
        assertEq(expected, 0.015 ether / 2); // 0.0075 ether
        
        // 再存入更多
        vm.prank(user1);
        bank.deposit{value: 0.01 ether}(); // 总共 0.025 ether
        
        expected = bank.getExpectedTransferAmount();
        assertEq(expected, 0.025 ether / 2); // 0.0125 ether
    }

    function testOptimizedCalculation() public {
        // 存入资金
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        // 测试 checkUpkeep 返回正确的数据格式
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        // 验证新的数据格式
        (uint256 balance, uint256 timestamp) = abi.decode(performData, (uint256, uint256));
        assertEq(balance, 0.02 ether);
        assertEq(timestamp, block.timestamp);
        
        // 测试 getExpectedTransferAmount 函数
        uint256 expectedAmount = bank.getExpectedTransferAmount();
        assertEq(expectedAmount, 0.01 ether); // 0.02 / 2
        
        // 执行 performUpkeep 并验证结果
        uint256 ownerBalanceBefore = address(this).balance;
        bank.performUpkeep(performData);
        uint256 ownerBalanceAfter = address(this).balance;
        
        // 验证转账金额正确
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedAmount);
        
        console.log("Optimization test passed: no duplicate calculations, good data consistency");
    }
    
    // 接收ETH用于测试
    receive() external payable {}
} 
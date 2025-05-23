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
        
        // 解码 performData 验证数据正确性
        uint256 encodedAmount = abi.decode(performData, (uint256));
        uint256 expectedAmount = 0.015 ether / 2;
        assertEq(encodedAmount, expectedAmount);
        
        // 使用返回的 performData 执行自动化
        uint256 ownerBalanceBefore = address(this).balance;
        bank.performUpkeep(performData);
        uint256 ownerBalanceAfter = address(this).balance;
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, expectedAmount);
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
        // 测试1: 验证 performData 路径（使用预计算数据）
        vm.prank(user1);
        bank.deposit{value: 0.02 ether}();
        
        // 获取 performData（这时余额是 0.02 ETH）
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertTrue(performData.length > 0);
        
        // 解码查看预计算的数据
        uint256 precomputedAmount = abi.decode(performData, (uint256));
        assertEq(precomputedAmount, 0.01 ether); // 0.02 ETH / 2
        
        uint256 ownerBalance1 = address(this).balance;
        bank.performUpkeep(performData); // 使用预计算的金额
        uint256 transferred1 = address(this).balance - ownerBalance1;
        assertEq(transferred1, 0.01 ether);
        
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
    
    // 接收ETH用于测试
    receive() external payable {}
} 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");

        vm.startPrank(owner);
        bank = new Bank();
        vm.stopPrank();
    }

    function test_Deposit() public {
        // 测试存款
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(bank).call{value: 1 ether}("");
        assertTrue(success, "Deposit failed");
        assertEq(bank.balances(user1), 1 ether, "Balance incorrect");
        assertTrue(bank.isDeposit(user1), "Deposit status incorrect");
    }

    function test_MultipleDeposits() public {
        // 测试多个用户存款
        vm.deal(user1, 2 ether);
        vm.deal(user2, 3 ether);
        vm.deal(user3, 4 ether);
        vm.deal(user4, 5 ether);

        // 用户1存款
        vm.prank(user1);
        (bool success1,) = address(bank).call{value: 2 ether}("");
        assertTrue(success1, "User1 deposit failed");

        // 用户2存款
        vm.prank(user2);
        (bool success2,) = address(bank).call{value: 3 ether}("");
        assertTrue(success2, "User2 deposit failed");

        // 用户3存款
        vm.prank(user3);
        (bool success3,) = address(bank).call{value: 4 ether}("");
        assertTrue(success3, "User3 deposit failed");

        // 用户4存款
        vm.prank(user4);
        (bool success4,) = address(bank).call{value: 5 ether}("");
        assertTrue(success4, "User4 deposit failed");

        // 检查余额
        assertEq(bank.balances(user1), 2 ether, "User1 balance incorrect");
        assertEq(bank.balances(user2), 3 ether, "User2 balance incorrect");
        assertEq(bank.balances(user3), 4 ether, "User3 balance incorrect");
        assertEq(bank.balances(user4), 5 ether, "User4 balance incorrect");
    }

    function test_Top3Depositors() public {
        // 测试前三名存款人
        vm.deal(user1, 2 ether);
        vm.deal(user2, 3 ether);
        vm.deal(user3, 4 ether);
        vm.deal(user4, 5 ether);

        // 存款
        vm.prank(user1);
        (bool success1,) = address(bank).call{value: 2 ether}("");
        assertTrue(success1, "User1 deposit failed");
        vm.prank(user2);
        (bool success2,) = address(bank).call{value: 3 ether}("");
        assertTrue(success2, "User2 deposit failed");
        vm.prank(user3);
        (bool success3,) = address(bank).call{value: 4 ether}("");
        assertTrue(success3, "User3 deposit failed");
        vm.prank(user4);
        (bool success4,) = address(bank).call{value: 5 ether}("");
        assertTrue(success4, "User4 deposit failed");
        // 检查前三名
        address[3] memory top3 = bank.getTop3Depositor();
        assertEq(top3[0], user4, "First place incorrect");
        assertEq(top3[1], user3, "Second place incorrect");
        assertEq(top3[2], user2, "Third place incorrect");
    }

    function test_Top10Depositors() public {
        // 测试前10名存款人
        address[11] memory users;
        for(uint i = 0; i < 11; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(users[i], (i + 1) * 1 ether);
            vm.prank(users[i]);
            (bool success,) = address(bank).call{value: (i + 1) * 1 ether}("");
            assertTrue(success, "Deposit failed");
        }

        // 检查前10名
        (address[] memory top10Users, uint256[] memory top10Amounts) = bank.getTop10Depositors();
        
        // 验证长度
        assertEq(top10Users.length, 10, "Top 10 length incorrect");
        assertEq(top10Amounts.length, 10, "Top 10 amounts length incorrect");

        // 验证排序
        for(uint i = 0; i < 9; i++) {
            assertTrue(top10Amounts[i] >= top10Amounts[i + 1], "Amounts not in descending order");
        }

        // 验证最高存款
        assertEq(top10Users[0], users[10], "Highest depositor incorrect");
        assertEq(top10Amounts[0], 11 ether, "Highest amount incorrect");
    }

    function test_Withdraw() public {
        // 测试提现
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(bank).call{value: 1 ether}("");
        assertTrue(success, "Deposit failed");

        // 记录初始余额
        uint256 initialBalance = owner.balance;

        // 提现
        vm.prank(owner);
        bank.withdraw();

        // 检查余额
        assertEq(owner.balance, initialBalance + 1 ether, "Withdrawal amount incorrect");
        assertEq(address(bank).balance, 0, "Contract balance should be 0");
    }

    function test_WithdrawNotOwner() public {
        // 测试非所有者提现
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        (bool success,) = address(bank).call{value: 1 ether}("");
        assertTrue(success, "Deposit failed");

        // 尝试提现
        vm.prank(user1);
        vm.expectRevert();
        bank.withdraw();
    }

    function test_ZeroDeposit() public {
        // 测试零存款
        vm.prank(user1);
        vm.expectRevert("Amount must > 0");
        (bool success,) = address(bank).call{value: 0}("");
        assertTrue(success, "Deposit failed");
    }
}
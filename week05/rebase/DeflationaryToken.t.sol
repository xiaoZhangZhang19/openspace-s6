// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/rebase/DeflationaryToken.sol";

contract DeflationaryTokenTest is Test {
    DeflationaryToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        // 部署代币 - 部署者（测试合约）获得初始供应量
        token = new DeflationaryToken();
        
        // 为测试向用户转移一些代币
        token.transfer(user1, 10_000_000 * 10**18); // 给user1转1000万代币
        token.transfer(user2, 5_000_000 * 10**18);  // 给user2转500万代币
    }

    function testInitialSupply() public view {
        assertEq(token.totalSupply(), 100_000_000 * 10**18, "Initial supply should be 100 million");
    }

    function testInitialBalances() public view {
        assertEq(token.balanceOf(user1), 10_000_000 * 10**18, "User1 should have 10 million tokens");
        assertEq(token.balanceOf(user2), 5_000_000 * 10**18, "User2 should have 5 million tokens");
        assertEq(token.balanceOf(owner), 85_000_000 * 10**18, "Owner should have 85 million tokens");
    }

    function testTransfer() public {
        uint256 initialUser1Balance = token.balanceOf(user1);
        uint256 initialUser2Balance = token.balanceOf(user2);
        
        vm.prank(user1);
        token.transfer(user2, 1_000_000 * 10**18); // 转移100万代币
        
        assertEq(token.balanceOf(user1), initialUser1Balance - 1_000_000 * 10**18, "User1 balance should decrease by 1 million");
        assertEq(token.balanceOf(user2), initialUser2Balance + 1_000_000 * 10**18, "User2 balance should increase by 1 million");
    }

    function testRebaseFailsBeforePeriod() public {
        // 在周期结束前尝试重新基数
        vm.expectRevert("Rebase period not elapsed");
        token.rebase();
    }

    function testRebase() public {
        uint256 initialTotalSupply = token.totalSupply();
        uint256 initialUser1Balance = token.balanceOf(user1);
        uint256 initialUser2Balance = token.balanceOf(user2);
        uint256 initialOwnerBalance = token.balanceOf(owner);
        
        // 向前跳过1年
        vm.warp(block.timestamp + 365 days);
        
        // 执行重新基数
        token.rebase();
        
        // 计算1%减少后的预期值
        uint256 expectedTotalSupply = (initialTotalSupply * 99) / 100;
        uint256 expectedUser1Balance = (initialUser1Balance * 99) / 100;
        uint256 expectedUser2Balance = (initialUser2Balance * 99) / 100;
        uint256 expectedOwnerBalance = (initialOwnerBalance * 99) / 100;
        
        // 验证新的总供应量（减少1%）
        assertEq(token.totalSupply(), expectedTotalSupply, "Total supply should decrease by 1%");
        
        // 验证余额按比例减少
        assertApproxEqAbs(token.balanceOf(user1), expectedUser1Balance, 10, "User1 balance should decrease by 1%");
        assertApproxEqAbs(token.balanceOf(user2), expectedUser2Balance, 10, "User2 balance should decrease by 1%");
        assertApproxEqAbs(token.balanceOf(owner), expectedOwnerBalance, 10, "Owner balance should decrease by 1%");
    }

    function testMultipleRebaseOperations() public {
        uint256 initialTotalSupply = token.totalSupply();
        
        // 为第一次重新基数向前跳过1年
        vm.warp(block.timestamp + 365 days);
        token.rebase();
        
        uint256 supplyAfterFirstRebase = token.totalSupply();
        assertEq(supplyAfterFirstRebase, (initialTotalSupply * 99) / 100, "Total supply should decrease by 1% after first rebase");
        
        // 使用测试函数重置上次重新基数时间
        // 这模拟自上次重新基数已过去一年
        token.setLastRebaseTimeForTesting(block.timestamp - 365 days);
        
        // 为第二次重新基数向前跳过
        vm.warp(block.timestamp + 1); // 只需要在lastRebaseTime之后
        token.rebase();
        
        uint256 supplyAfterSecondRebase = token.totalSupply();
        assertEq(supplyAfterSecondRebase, (supplyAfterFirstRebase * 99) / 100, "Total supply should decrease by 1% after second rebase");
        
        // 验证多次重新基数的复合效应
        // 2年后，总供应量应约为初始值的98.01%（0.99 * 0.99 = 0.9801）
        uint256 expectedSupplyAfterTwoYears = (initialTotalSupply * 99 * 99) / 10000;
        assertApproxEqAbs(supplyAfterSecondRebase, expectedSupplyAfterTwoYears, 10, "Total supply should be about 98.01% of initial after 2 rebases");
    }

    function testTransferAfterRebase() public {
        // 向前跳过1年并执行重新基数
        vm.warp(block.timestamp + 365 days);
        token.rebase();
        
        uint256 user1BalanceAfterRebase = token.balanceOf(user1);
        uint256 user2BalanceAfterRebase = token.balanceOf(user2);
        
        // 重新基数后转移代币
        uint256 transferAmount = 1_000_000 * 10**18; // 100万代币
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        // 使用近似相等验证余额，考虑可能的舍入问题
        assertApproxEqAbs(token.balanceOf(user1), user1BalanceAfterRebase - transferAmount, 10, "User1 balance should decrease by transfer amount");
        assertApproxEqAbs(token.balanceOf(user2), user2BalanceAfterRebase + transferAmount, 10, "User2 balance should increase by transfer amount");
    }

    function testSharesVsBalances() public {
        // 检查初始份额
        uint256 initialUser1Shares = token.sharesOf(user1);
        
        // 向前跳过1年并执行重新基数
        vm.warp(block.timestamp + 365 days);
        token.rebase();
        
        // 验证份额保持不变但余额减少
        assertEq(token.sharesOf(user1), initialUser1Shares, "Shares should remain constant after rebase");
        assertLt(token.balanceOf(user1), 10_000_000 * 10**18, "Balance should decrease after rebase");
    }

    function testCustomMintAndBurn() public {
        // 测试铸造新代币
        uint256 initialSupply = token.totalSupply();
        uint256 mintAmount = 5_000_000 * 10**18; // 500万代币
        
        token.mint(user1, mintAmount);
        
        assertEq(token.totalSupply(), initialSupply + mintAmount, "Total supply should increase after minting");
        assertEq(token.balanceOf(user1), 15_000_000 * 10**18, "User1 balance should increase by mint amount");
        
        // 测试销毁代币
        vm.prank(user1);
        token.burn(user1, 2_000_000 * 10**18); // 销毁200万代币
        
        assertEq(token.totalSupply(), initialSupply + mintAmount - 2_000_000 * 10**18, "Total supply should decrease after burning");
        assertEq(token.balanceOf(user1), 13_000_000 * 10**18, "User1 balance should decrease by burn amount");
    }
} 
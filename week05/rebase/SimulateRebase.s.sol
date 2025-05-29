// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/rebase/DeflationaryToken.sol";

contract SimulateRebase is Script {
    function run() external {
        // 使用硬编码的私钥进行模拟 - 这对于本地模拟来说是可以的
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; // Anvil默认私钥
        address user1 = vm.addr(0x1);
        address user2 = vm.addr(0x2);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署通缩代币
        DeflationaryToken token = new DeflationaryToken();
        
        console.log("DeflationaryToken deployed at:", address(token));
        console.log("Initial total supply:", token.totalSupply() / 1e18, "tokens");
        
        // 向用户转移一些代币
        token.transfer(user1, 10_000_000 * 10**18); // 给user1转1000万代币
        token.transfer(user2, 5_000_000 * 10**18);  // 给user2转500万代币
        
        // 显示初始余额
        console.log("--- Initial State ---");
        console.log("User1 balance:", token.balanceOf(user1) / 1e18, "tokens");
        console.log("User2 balance:", token.balanceOf(user2) / 1e18, "tokens");
        console.log("Deployer balance:", token.balanceOf(msg.sender) / 1e18, "tokens");
        console.log("Total supply:", token.totalSupply() / 1e18, "tokens");
        
        // 模拟5年的重新基数
        for (uint i = 1; i <= 5; i++) {
            // 向前跳过1年或直接设置上次重新基数时间
            if (i == 1) {
                // 对于第一次重新基数，直接向前跳过一年
                vm.warp(block.timestamp + 365 days);
            } else {
                // 对于后续的重新基数，重置lastRebaseTime以模拟已经过了一年
                token.setLastRebaseTimeForTesting(block.timestamp - 365 days);
                vm.warp(block.timestamp + 1); // 只需要在lastRebaseTime之后
            }
            
            // 执行重新基数
            token.rebase();
            
            // 显示每年后的余额
            console.log("--- After Year", i, "---");
            console.log("User1 balance:", token.balanceOf(user1) / 1e18, "tokens");
            console.log("User2 balance:", token.balanceOf(user2) / 1e18, "tokens");
            console.log("Deployer balance:", token.balanceOf(msg.sender) / 1e18, "tokens");
            console.log("Total supply:", token.totalSupply() / 1e18, "tokens");
            
            // 计算占原始供应量的百分比
            uint256 percentOfOriginal = (token.totalSupply() * 100) / (100_000_000 * 10**18);
            console.log("Percent of original supply:", percentOfOriginal, "%");
        }
        
        // 演示重新基数后的转账
        console.log("--- Transfer After Rebases ---");
        
        // 我们将从部署者向user1转账，而不是尝试从user1向user2转账
        // 这简化了脚本，因为我们已经以部署者身份广播
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 deployerBalanceBefore = token.balanceOf(msg.sender);
        
        console.log("Deployer balance before transfer:", deployerBalanceBefore / 1e18, "tokens");
        console.log("User1 balance before transfer:", user1BalanceBefore / 1e18, "tokens");
        
        // 从部署者向user1转100万代币
        uint256 transferAmount = 1_000_000 * 10**18;
        token.transfer(user1, transferAmount);
        
        console.log("Deployer balance after transfer:", token.balanceOf(msg.sender) / 1e18, "tokens");
        console.log("User1 balance after transfer:", token.balanceOf(user1) / 1e18, "tokens");
        
        vm.stopBroadcast();
    }
} 
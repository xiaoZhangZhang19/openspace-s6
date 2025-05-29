// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/stakeWithAave/KKToken.sol";
import "../../src/stakeWithAave/StakingPool.sol";
import "../../src/stakeWithAave/IAave.sol";

/**
 * @title TestAaveUnstakeFinal
 * @notice Final test script focusing on unstake after emergency withdraw
 */
contract TestAaveUnstakeFinal is Script {
    // Aave v2 mainnet contract addresses
    address constant AAVE_LENDING_POOL_MAINNET = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    address constant AAVE_WETH_GATEWAY_MAINNET = 0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04;
    address constant AAVE_AWETH_MAINNET = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e;
    address constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Test parameters
    uint256 constant TEST_STAKE_AMOUNT = 1 ether;
    
    function run() public {
        // Use default Anvil private key
        uint256 testPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address testUser = vm.addr(testPrivateKey);
        
        // Ensure test user has enough ETH
        vm.deal(testUser, 10 ether);
        
        console.log("===== TESTING UNSTAKE AFTER EMERGENCY WITHDRAW =====");
        console.log("Test user address:", testUser);
        console.log("Initial ETH balance:", testUser.balance / 1 ether, "ETH");
        
        vm.startBroadcast(testPrivateKey);
        
        // Deploy KK Token
        KKToken kkToken = new KKToken();
        console.log("KK Token deployed at:", address(kkToken));
        
        // Deploy StakingPool
        StakingPool stakingPool = new StakingPool(
            address(kkToken),
            AAVE_WETH_GATEWAY_MAINNET,
            AAVE_LENDING_POOL_MAINNET,
            AAVE_AWETH_MAINNET,
            WETH_MAINNET
        );
        console.log("Staking Pool deployed at:", address(stakingPool));
        
        // Set KK Token minter to StakingPool
        kkToken.setMinter(address(stakingPool));
        
        // Step 1: Stake ETH
        console.log("\n--- Step 1: Staking ETH ---");
        console.log("Staking amount:", TEST_STAKE_AMOUNT / 1 ether, "ETH");
        
        stakingPool.stake{value: TEST_STAKE_AMOUNT}();
        
        console.log("User ETH balance after stake:", testUser.balance / 1 ether, "ETH");
        console.log("User staked amount:", stakingPool.balanceOf(testUser) / 1 ether, "ETH");
        console.log("aWETH balance:", stakingPool.getAWethBalance() / 1 ether, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1 ether, "ETH");
        
        // Step 2: Emergency withdraw
        console.log("\n--- Step 2: Emergency Withdraw ---");
        stakingPool.emergencyWithdraw();
        
        console.log("User ETH balance after emergency withdraw:", testUser.balance / 1 ether, "ETH");
        console.log("User staked amount:", stakingPool.balanceOf(testUser) / 1 ether, "ETH");
        console.log("aWETH balance:", stakingPool.getAWethBalance() / 1 ether, "ETH");
        console.log("Total staked:", stakingPool.totalStaked() / 1 ether, "ETH");
        
        // Step 3: Try to unstake after emergency withdraw
        console.log("\n--- Step 3: Unstaking After Emergency Withdraw ---");
        
        uint256 remainingStake = stakingPool.balanceOf(testUser);
        console.log("Remaining staked amount:", remainingStake / 1 ether, "ETH");
        
        if (remainingStake > 0) {
            uint256 balanceBefore = testUser.balance;
            stakingPool.unstake(remainingStake);
            
            console.log("ETH received from unstake:", (testUser.balance - balanceBefore) / 1 ether, "ETH");
            console.log("User staked amount after unstake:", stakingPool.balanceOf(testUser) / 1 ether, "ETH");
        } else {
            console.log("No remaining stake to unstake");
        }
        
        console.log("===== TEST COMPLETED =====");
        vm.stopBroadcast();
    }
} 
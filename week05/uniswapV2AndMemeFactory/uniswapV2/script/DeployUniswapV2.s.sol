// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Factory.sol";
import "../src/periphery/WETH.sol";
import "../src/periphery/UniswapV2Router.sol";

contract DeployUniswapV2 is Script {
    function run() external {
        // 使用anvil默认提供的第一个账户私钥
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署Uniswap V2 Factory
        console.log("Deploying Uniswap V2 Factory...");
        UniswapV2Factory factory = new UniswapV2Factory(deployer);
        console.log("Uniswap V2 Factory deployed at:", address(factory));
        
        // 2. 部署WETH
        console.log("Deploying WETH...");
        WETH weth = new WETH();
        console.log("WETH deployed at:", address(weth));
        
        // 3. 部署Uniswap V2 Router
        console.log("Deploying Uniswap V2 Router...");
        UniswapV2Router router = new UniswapV2Router(address(factory), address(weth));
        console.log("Uniswap V2 Router deployed at:", address(router));
        
        vm.stopBroadcast();
        
        // 总结部署地址
        console.log("\n==== DEPLOYMENT SUMMARY ====");
        console.log("Uniswap V2 Factory: ", address(factory));
        console.log("WETH:              ", address(weth));
        console.log("Uniswap V2 Router: ", address(router));
    }
} 
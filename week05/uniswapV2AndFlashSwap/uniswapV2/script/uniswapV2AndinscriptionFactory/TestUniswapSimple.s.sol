// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../../src/periphery/UniswapV2Router.sol";
import "../../src/core/UniswapV2Factory.sol";
import "../../src/periphery/WETH.sol";
import "../../src/periphery/ERC20.sol"; // 使用Uniswap自己的ERC20实现

contract TestUniswapSimple is Script {
    // 已部署的Uniswap合约地址
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address payable constant ROUTER_ADDRESS = payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
    
    // 测试代币
    ERC20 public tokenA;
    ERC20 public tokenB;
    
    function run() external {
        // 使用anvil默认提供的第一个账户私钥
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署两个测试代币
        console.log("Deploying test tokens...");
        tokenA = new ERC20("Token A", "TKNA", 1000000 ether);
        tokenB = new ERC20("Token B", "TKNB", 1000000 ether);
        
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        
        // 2. 获取已部署的Uniswap合约
        UniswapV2Router router = UniswapV2Router(ROUTER_ADDRESS);
        UniswapV2Factory factory = UniswapV2Factory(FACTORY_ADDRESS);
        
        // 3. 添加Token A和WETH的流动性
        console.log("\nAdding liquidity for Token A and WETH...");
        
        // 首先批准路由器使用代币
        uint256 tokenAmount = 1000 ether;
        uint256 ethAmount = 5 ether;
        
        tokenA.approve(ROUTER_ADDRESS, tokenAmount);
        
        // 添加代币和ETH的流动性
        router.addLiquidityETH{value: ethAmount}(
            address(tokenA),
            tokenAmount,
            0, // 最小代币数量
            0, // 最小ETH数量
            deployer, // LP接收者
            block.timestamp + 15 minutes // 截止时间
        );
        
        // 4. 添加Token A和Token B的流动性
        console.log("\nAdding liquidity for Token A and Token B...");
        
        tokenA.approve(ROUTER_ADDRESS, tokenAmount);
        tokenB.approve(ROUTER_ADDRESS, tokenAmount);
        
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            tokenAmount,
            tokenAmount,
            0, // 最小Token A数量
            0, // 最小Token B数量
            deployer, // LP接收者
            block.timestamp + 15 minutes // 截止时间
        );
        
        // 5. 验证交易对已创建
        address pairTokenAWETH = factory.getPair(address(tokenA), WETH_ADDRESS);
        address pairTokenAB = factory.getPair(address(tokenA), address(tokenB));
        
        console.log("\nCreated pairs:");
        console.log("Token A - WETH pair:", pairTokenAWETH);
        console.log("Token A - Token B pair:", pairTokenAB);
        
        // 6. 测试兑换
        console.log("\nTesting swap...");
        
        // 使用0.1 ETH购买Token A
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = address(tokenA);
        
        uint256 balanceTokenABefore = tokenA.balanceOf(deployer);
        
        router.swapExactETHForTokens{value: 0.1 ether}(
            0, // 最小输出数量
            path,
            deployer,
            block.timestamp + 15 minutes
        );
        
        uint256 balanceTokenAAfter = tokenA.balanceOf(deployer);
        uint256 receivedTokenA = balanceTokenAAfter - balanceTokenABefore;
        
        console.log("Swapped 0.1 ETH for", receivedTokenA / 1e18, "Token A");
        
        vm.stopBroadcast();
    }
} 
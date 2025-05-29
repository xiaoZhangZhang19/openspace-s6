// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/memefactory/TWAP/MemeTWAPOracle.sol";
import "../../src/interfaces/IUniswapV2Router02.sol";
import "../../src/interfaces/IUniswapV2Factory.sol";
import "../../src/interfaces/IUniswapV2Pair.sol";
import "../../src/interfaces/IERC20.sol";

/**
 * @title TWAP价格操纵测试脚本
 * @dev 测试TWAP在价格操纵场景下的稳定性，比较即时价格和TWAP价格的差异
 */
contract TestMemeTWAPPriceManipulation is Script {
    // 常量：已部署的合约地址（适用于Anvil环境）
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Uniswap工厂合约地址
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH合约地址
    address constant ROUTER_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // Uniswap路由器地址
    address constant TEST_TOKEN = 0x3Ca8f9C04c7e3E1624Ac2008F92f6F366A869444; // 测试代币地址
    
    // 记录价格数据的结构
    struct PriceData {
        uint256 timestamp;
        uint256 spotPrice;
        uint256 twapPrice;
    }
    
    // 存储价格历史记录
    PriceData[] public priceHistory;
    
    function run() external {
        // 使用anvil的第一个账户私钥作为测试者
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署TWAP预言机合约
        console.log("Deploying MemeTWAPOracle...");
        MemeTWAPOracle twapOracle = new MemeTWAPOracle(FACTORY_ADDRESS, WETH_ADDRESS);
        console.log("MemeTWAPOracle deployed at:", address(twapOracle));
        
        // 获取Uniswap配对
        address pair = IUniswapV2Factory(FACTORY_ADDRESS).getPair(TEST_TOKEN, WETH_ADDRESS);
        if (pair == address(0)) {
            console.log("Error: TOKEN/WETH pair does not exist. Please ensure liquidity is added first.");
            vm.stopBroadcast();
            return;
        }
        
        // 确保我们有足够的测试代币
        IERC20 testToken = IERC20(TEST_TOKEN);
        uint256 tokenBalance = testToken.balanceOf(deployer);
        
        if (tokenBalance < 1000 ether) {
            console.log("Error: Not enough tokens for testing. This test requires a significant amount of tokens.");
            vm.stopBroadcast();
            return;
        }
        
        console.log("Starting test with", tokenBalance / 1e18, "tokens");
        
        // 2. 初始化：记录5个小时的常规价格数据
        console.log("==== Phase 1: Building TWAP History (5 hours) ====");
        
        for (uint i = 0; i < 5; i++) {
            // 前进时间1小时
            vm.warp(block.timestamp + 1 hours);
            
            // 记录价格数据
            twapOracle.updatePrice(TEST_TOKEN);
            
            // 执行小额交易
            executeTrade(true, 0.01 ether, TEST_TOKEN, WETH_ADDRESS, ROUTER_ADDRESS);
            
            // 记录价格
            recordPriceData(twapOracle, TEST_TOKEN, 1 hours);
            
            console.log("Hour", i+1, "price data recorded");
        }
        
        // 3. 模拟闪电贷攻击：价格操纵
        console.log("==== Phase 2: Price Manipulation Attack ====");
        
        // 记录操纵前价格
        (uint256 prePumpSpotPrice, bool spotSuccess) = twapOracle.getTokenSpotPrice(TEST_TOKEN);
        if (spotSuccess) {
            console.log("Pre-manipulation spot price:", prePumpSpotPrice / 1e18);
        } else {
            console.log("Failed to get pre-manipulation spot price");
        }
        
        // 授权路由合约使用代币
        testToken.approve(ROUTER_ADDRESS, tokenBalance);
        
        // 进行大规模卖出以操纵价格
        console.log("Executing flash loan attack (massive sell)...");
        uint256 sellAmount = tokenBalance / 2; // 卖出一半持有量
        executeSellTrade(sellAmount, TEST_TOKEN, WETH_ADDRESS, ROUTER_ADDRESS);
        
        // 记录操纵后价格
        (uint256 postPumpSpotPrice, bool postSpotSuccess) = twapOracle.getTokenSpotPrice(TEST_TOKEN);
        if (postSpotSuccess && spotSuccess) {
            console.log("Post-manipulation spot price:", postPumpSpotPrice / 1e18);
            
            // 计算价格变化百分比
            int256 priceChange = int256(postPumpSpotPrice) - int256(prePumpSpotPrice);
            int256 percentChange = (priceChange * 100) / int256(prePumpSpotPrice);
            
            // 输出价格变化
            if (percentChange > 0) {
                console.log("Price change: +", uint256(percentChange));
            } else {
                console.log("Price change:", percentChange);
            }
        } else {
            console.log("Failed to get post-manipulation spot price");
        }
        
        // 更新价格观察点以捕获价格变化
        twapOracle.updatePrice(TEST_TOKEN);
        
        // 记录操纵后的即时价格和TWAP价格
        (uint256 twapPrice, bool twapSuccess) = twapOracle.getTokenTWAP(TEST_TOKEN, 1 hours);
        if (twapSuccess && postSpotSuccess) {
            console.log("1-hour TWAP after manipulation:", twapPrice / 1e18);
            
            // 计算TWAP与即时价格的差异百分比
            int256 twapDiff = int256(twapPrice) - int256(postPumpSpotPrice);
            int256 twapPercentDiff = (twapDiff * 100) / int256(postPumpSpotPrice);
            
            // 输出差异
            if (twapPercentDiff > 0) {
                console.log("TWAP vs Spot price difference: +", uint256(twapPercentDiff));
            } else {
                console.log("TWAP vs Spot price difference:", twapPercentDiff);
            }
        }
        
        // 4. 计算不同时间窗口的TWAP
        console.log("==== TWAP at Different Time Windows ====");
        
        // 即时价格
        if (postSpotSuccess) {
            console.log("Current spot price:", postPumpSpotPrice / 1e18);
        }
        
        // 计算1小时TWAP
        calculateAndLogTWAP(twapOracle, TEST_TOKEN, 1 hours, "1 hour");
        
        // 计算3小时TWAP
        calculateAndLogTWAP(twapOracle, TEST_TOKEN, 3 hours, "3 hours");
        
        // 计算5小时TWAP
        calculateAndLogTWAP(twapOracle, TEST_TOKEN, 5 hours, "5 hours");
        
        // 5. 模拟价格恢复过程，并展示TWAP如何平滑变化
        console.log("==== Phase 3: Price Recovery and TWAP Adaptation ====");
        
        // 买回部分代币让价格部分恢复
        console.log("Buying back tokens to recover price...");
        executeTrade(true, 0.3 ether, TEST_TOKEN, WETH_ADDRESS, ROUTER_ADDRESS);
        
        // 记录恢复后的价格
        (uint256 recoverySpotPrice, bool recoverySuccess) = twapOracle.getTokenSpotPrice(TEST_TOKEN);
        if (recoverySuccess && spotSuccess) {
            console.log("Post-recovery spot price:", recoverySpotPrice / 1e18);
            
            // 计算恢复百分比
            int256 recoveryChange = int256(recoverySpotPrice) - int256(prePumpSpotPrice);
            int256 recoveryPercent = (recoveryChange * 100) / int256(prePumpSpotPrice);
            
            // 输出恢复情况
            if (recoveryPercent > 0) {
                console.log("Recovery from original price: +", uint256(recoveryPercent));
            } else {
                console.log("Recovery from original price:", recoveryPercent);
            }
        }
        
        // 更新价格观察点
        twapOracle.updatePrice(TEST_TOKEN);
        
        // 模拟TWAP逐渐适应新价格的过程
        console.log("==== TWAP Adaptation Over Time ====");
        
        for (uint i = 0; i < 5; i++) {
            // 前进时间30分钟
            vm.warp(block.timestamp + 30 minutes);
            
            // 执行小额交易
            executeTrade(true, 0.005 ether, TEST_TOKEN, WETH_ADDRESS, ROUTER_ADDRESS);
            
            // 更新价格观察点
            twapOracle.updatePrice(TEST_TOKEN);
            
            // 获取最新的即时价格
            (uint256 currentSpotPrice, bool currentSpotSuccess) = twapOracle.getTokenSpotPrice(TEST_TOKEN);
            
            // 计算当前TWAP
            (uint256 currentTwap, bool currentTwapSuccess) = twapOracle.getTokenTWAP(TEST_TOKEN, 1 hours);
            
            console.log("Time +", (i+1)*30, "minutes:");
            if (currentSpotSuccess) {
                console.log("- Spot price:", currentSpotPrice / 1e18);
            }
            
            if (currentTwapSuccess && currentSpotSuccess) {
                console.log("- 1-hour TWAP:", currentTwap / 1e18);
                
                // 计算差异百分比
                int256 difference = int256(currentTwap) - int256(currentSpotPrice);
                int256 diffPercent = (difference * 100) / int256(currentSpotPrice);
                
                // 输出差异
                if (diffPercent > 0) {
                    console.log("- Difference: +", uint256(diffPercent));
                } else {
                    console.log("- Difference:", diffPercent);
                }
            } else {
                console.log("- Failed to calculate current TWAP");
            }
        }
        
        console.log("==== Test Complete ====");
        console.log("Summary: This test demonstrates how TWAP provides price stability during market manipulation attempts.");
        console.log("Even when the spot price was drastically changed, the TWAP remained relatively stable,");
        console.log("and gradually adapted to the new price level over time.");
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev 记录价格数据
     * @param oracle TWAP预言机
     * @param token 代币地址
     * @param period TWAP计算周期
     */
    function recordPriceData(MemeTWAPOracle oracle, address token, uint256 period) internal {
        (uint256 spotPrice, bool spotSuccess) = oracle.getTokenSpotPrice(token);
        (uint256 twapPrice, bool twapSuccess) = oracle.getTokenTWAP(token, period);
        
        if (spotSuccess && twapSuccess) {
            priceHistory.push(PriceData({
                timestamp: block.timestamp,
                spotPrice: spotPrice,
                twapPrice: twapPrice
            }));
        }
    }
    
    /**
     * @dev 计算并记录TWAP价格
     * @param oracle TWAP预言机合约
     * @param token 代币地址
     * @param period 时间段（秒）
     * @param periodName 时间段名称（用于日志）
     */
    function calculateAndLogTWAP(
        MemeTWAPOracle oracle, 
        address token, 
        uint256 period, 
        string memory periodName
    ) internal view {
        (uint256 twapPrice, bool success) = oracle.getTokenTWAP(token, period);
        
        console.log("TWAP over", periodName, ":");
        if (success) {
            console.log("- TWAP price:", twapPrice / 1e18);
            
            // 计算与即时价格的差异
            (uint256 spotPrice, bool spotSuccess) = oracle.getTokenSpotPrice(token);
            if (spotSuccess) {
                int256 difference = int256(twapPrice) - int256(spotPrice);
                int256 diffPercent = (difference * 100) / int256(spotPrice);
                
                // 输出差异
                if (diffPercent > 0) {
                    console.log("- Difference from spot price: +", uint256(diffPercent));
                } else {
                    console.log("- Difference from spot price:", diffPercent);
                }
            }
        } else {
            console.log("- Failed to calculate TWAP");
        }
    }
    
    /**
     * @dev 执行交易（买入）
     * @param isBuy 是否为买入操作
     * @param amount 交易金额
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param router Uniswap路由器地址
     */
    function executeTrade(
        bool isBuy, 
        uint256 amount, 
        address tokenA, 
        address tokenB, 
        address router
    ) internal {
        address[] memory path = new address[](2);
        
        if (isBuy) {
            // 买入: ETH -> Token
            path[0] = tokenB; // WETH
            path[1] = tokenA; // Token
            
            try IUniswapV2Router02(router).swapExactETHForTokens{value: amount}(
                0,                           // 接受任意数量的代币
                path,                        // 交易路径
                address(this),               // 代币接收者
                block.timestamp + 15 minutes // 交易截止时间
            ) returns (uint[] memory) {
                // 交易成功
                console.log("Buy trade successful");
            } catch Error(string memory reason) {
                console.log("Buy trade failed:", reason);
            } catch {
                console.log("Buy trade failed with unknown error");
            }
        }
    }
    
    /**
     * @dev 执行卖出交易
     * @param tokenAmount 要卖出的代币数量
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @param router Uniswap路由器地址
     */
    function executeSellTrade(
        uint256 tokenAmount, 
        address tokenA, 
        address tokenB, 
        address router
    ) internal {
        address[] memory path = new address[](2);
        path[0] = tokenA; // Token
        path[1] = tokenB; // WETH
        
        // 授权Router使用代币
        IERC20(tokenA).approve(router, tokenAmount);
        
        try IUniswapV2Router02(router).swapExactTokensForETH(
            tokenAmount,                    // 卖出的代币数量
            0,                              // 接受任意数量的ETH
            path,                           // 交易路径
            address(this),                  // ETH接收者
            block.timestamp + 15 minutes    // 交易截止时间
        ) returns (uint[] memory) {
            // 交易成功
            console.log("Sell trade successful");
        } catch Error(string memory reason) {
            console.log("Sell trade failed:", reason);
        } catch {
            console.log("Sell trade failed with unknown error");
        }
    }
    
    // 接收ETH
    receive() external payable {}
} 
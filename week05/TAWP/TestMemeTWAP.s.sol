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
 * @title TWAP价格预言机测试脚本
 * @dev 测试脚本部署MemeTWAPOracle合约，并模拟不同时间的多个交易来测试TWAP功能
 */
contract TestMemeTWAP is Script {
    // 常量：已部署的合约地址（适用于Anvil环境）
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Uniswap工厂合约地址
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH合约地址
    address constant ROUTER_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // Uniswap路由器地址
    address constant PEPE_TOKEN = 0x3Ca8f9C04c7e3E1624Ac2008F92f6F366A869444; // 示例Meme代币地址
    
    // 模拟的时间间隔（秒）
    uint256 constant TIME_STEP = 3600; // 1小时
    
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
        address pair = IUniswapV2Factory(FACTORY_ADDRESS).getPair(PEPE_TOKEN, WETH_ADDRESS);
        if (pair == address(0)) {
            console.log("Warning: PEPE/WETH pair does not exist. Please ensure liquidity is added first.");
            vm.stopBroadcast();
            return;
        }
        
        console.log("PEPE/WETH pair:", pair);
        
        // 获取初始价格并记录初始价格观察点
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        bool isPepeToken0 = token0 == PEPE_TOKEN;
        
        uint256 pepeReserve = isPepeToken0 ? reserve0 : reserve1;
        uint256 wethReserve = isPepeToken0 ? reserve1 : reserve0;
        
        console.log("Initial reserves:");
        console.log("- PEPE:", pepeReserve / 1e18);
        console.log("- WETH:", wethReserve / 1e18);
        console.log("- Initial price (WETH/PEPE):", (wethReserve * 1e18) / pepeReserve);
        
        // 记录初始价格观察点
        twapOracle.updatePrice(PEPE_TOKEN);
        console.log("Initial price observation recorded");
        
        // 2. 模拟多次交易以创建价格变化
        // 我们将模拟不同价格场景：
        // - 第一次：价格正常波动（小额交易）
        // - 第二次：价格大幅上涨（大额买入）
        // - 第三次：价格崩盘（大额卖出）
        // - 第四次：价格回归（小额交易）
        
        // 获取代币合约实例
        IERC20 pepeToken = IERC20(PEPE_TOKEN);
        
        // 确保我们有足够的PEPE代币用于测试
        uint256 initialBalance = pepeToken.balanceOf(deployer);
        if (initialBalance < 1000 ether) {
            console.log("Warning: Not enough PEPE tokens for testing. Some test scenarios may fail.");
        }
        
        console.log("\n=== Scenario 1: Normal Price Fluctuation ===");
        // 前进时间1小时
        vm.warp(block.timestamp + TIME_STEP);
        
        // 小额交易：买入少量PEPE
        executeTrade(true, 0.01 ether, PEPE_TOKEN, WETH_ADDRESS);
        
        // 记录价格观察点
        twapOracle.updatePrice(PEPE_TOKEN);
        console.log("Price observation recorded after small buy");
        
        // 检查即时价格
        (uint256 spotPrice, bool spotSuccess) = twapOracle.getTokenSpotPrice(PEPE_TOKEN);
        if (spotSuccess) {
            console.log("Current spot price:", spotPrice / 1e18, "WETH per PEPE");
        }
        
        console.log("\n=== Scenario 2: Price Surge ===");
        // 前进时间1小时
        vm.warp(block.timestamp + TIME_STEP);
        
        // 大额交易：买入大量PEPE导致价格上涨
        executeTrade(true, 0.5 ether, PEPE_TOKEN, WETH_ADDRESS);
        
        // 记录价格观察点
        twapOracle.updatePrice(PEPE_TOKEN);
        console.log("Price observation recorded after large buy");
        
        // 检查即时价格
        (spotPrice, spotSuccess) = twapOracle.getTokenSpotPrice(PEPE_TOKEN);
        if (spotSuccess) {
            console.log("Current spot price:", spotPrice / 1e18, "WETH per PEPE");
        }
        
        console.log("\n=== Scenario 3: Price Crash ===");
        // 前进时间1小时
        vm.warp(block.timestamp + TIME_STEP);
        
        // 大额交易：卖出大量PEPE导致价格下跌
        // 首先需要计算我们有多少PEPE代币
        uint256 sellAmount = pepeToken.balanceOf(deployer) / 2; // 卖出一半持有量
        if (sellAmount > 0) {
            executeSellTrade(sellAmount, PEPE_TOKEN, WETH_ADDRESS);
        } else {
            console.log("Not enough PEPE tokens to sell");
        }
        
        // 记录价格观察点
        twapOracle.updatePrice(PEPE_TOKEN);
        console.log("Price observation recorded after large sell");
        
        // 检查即时价格
        (spotPrice, spotSuccess) = twapOracle.getTokenSpotPrice(PEPE_TOKEN);
        if (spotSuccess) {
            console.log("Current spot price:", spotPrice / 1e18, "WETH per PEPE");
        }
        
        console.log("\n=== Scenario 4: Price Recovery ===");
        // 前进时间1小时
        vm.warp(block.timestamp + TIME_STEP);
        
        // 中等交易：买入适量PEPE使价格部分恢复
        executeTrade(true, 0.2 ether, PEPE_TOKEN, WETH_ADDRESS);
        
        // 记录价格观察点
        twapOracle.updatePrice(PEPE_TOKEN);
        console.log("Price observation recorded after recovery buy");
        
        // 检查即时价格
        (spotPrice, spotSuccess) = twapOracle.getTokenSpotPrice(PEPE_TOKEN);
        if (spotSuccess) {
            console.log("Current spot price:", spotPrice / 1e18, "WETH per PEPE");
        }
        
        // 3. 计算不同时间窗口的TWAP
        console.log("\n=== TWAP Calculations ===");
        
        // 计算1小时TWAP
        calculateAndLogTWAP(twapOracle, PEPE_TOKEN, 1 hours, "1 hour");
        
        // 计算2小时TWAP
        calculateAndLogTWAP(twapOracle, PEPE_TOKEN, 2 hours, "2 hours");
        
        // 计算3小时TWAP
        calculateAndLogTWAP(twapOracle, PEPE_TOKEN, 3 hours, "3 hours");
        
        // 计算全周期TWAP
        calculateAndLogTWAP(twapOracle, PEPE_TOKEN, 4 hours, "Full period (4 hours)");
        
        // 检查是否有足够的价格历史
        console.log("\n=== Price History Sufficiency ===");
        
        bool has1HourHistory = twapOracle.hasSufficientPriceHistory(PEPE_TOKEN, 1 hours);
        bool has3HoursHistory = twapOracle.hasSufficientPriceHistory(PEPE_TOKEN, 3 hours);
        bool has1DayHistory = twapOracle.hasSufficientPriceHistory(PEPE_TOKEN, 1 days);
        
        console.log("Has 1 hour price history:", has1HourHistory);
        console.log("Has 3 hours price history:", has3HoursHistory);
        console.log("Has 1 day price history:", has1DayHistory);
        
        // 打印所有观察点数据
        console.log("\n=== All Price Observations ===");
        uint256 obsCount = twapOracle.getObservationsCount(PEPE_TOKEN);
        for (uint256 i = 0; i < obsCount; i++) {
            (uint256 timestamp, uint256 price0Cumulative, uint256 price1Cumulative) = 
                twapOracle.getObservation(PEPE_TOKEN, i);
            
            console.log("Observation", i);
            console.log("- Timestamp:", timestamp);
            console.log("- Price0Cumulative:", price0Cumulative);
            console.log("- Price1Cumulative:", price1Cumulative);
        }
        
        vm.stopBroadcast();
    }
    
    /**
     * @dev 执行交易（买入/卖出）
     * @param isBuy 是否为买入操作
     * @param amount 交易金额（如果是买入，则为ETH金额；如果是卖出，则为代币金额）
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     */
    function executeTrade(bool isBuy, uint256 amount, address tokenA, address tokenB) internal {
        address[] memory path = new address[](2);
        
        if (isBuy) {
            // 买入: ETH -> Token
            path[0] = tokenB; // WETH
            path[1] = tokenA; // 代币
            
            console.log("Executing buy: Swapping", amount / 1e18, "ETH for tokens");
            
            try IUniswapV2Router02(ROUTER_ADDRESS).swapExactETHForTokens{value: amount}(
                0,                           // 接受任意数量的代币
                path,                        // 交易路径
                address(this),               // 代币接收者
                block.timestamp + 15 minutes // 交易截止时间
            ) returns (uint[] memory amounts) {
                console.log("Buy successful! Received", amounts[1] / 1e18, "tokens");
                
                // 打印最新价格
                printCurrentPrice(tokenA, tokenB);
            } catch Error(string memory reason) {
                console.log("Buy failed:", reason);
            } catch {
                console.log("Buy failed with unknown error");
            }
        } else {
            // 卖出: Token -> ETH (我们在executeSellTrade函数中处理这种情况)
            console.log("Sell operation should use executeSellTrade function");
        }
    }
    
    /**
     * @dev 执行卖出交易
     * @param tokenAmount 要卖出的代币数量
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     */
    function executeSellTrade(uint256 tokenAmount, address tokenA, address tokenB) internal {
        address[] memory path = new address[](2);
        path[0] = tokenA; // 代币
        path[1] = tokenB; // WETH
        
        console.log("Executing sell: Swapping", tokenAmount / 1e18, "tokens for ETH");
        
        // 先授权Router使用代币
        IERC20(tokenA).approve(ROUTER_ADDRESS, tokenAmount);
        
        try IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForETH(
            tokenAmount,                    // 卖出的代币数量
            0,                              // 接受任意数量的ETH
            path,                           // 交易路径
            address(this),                  // ETH接收者
            block.timestamp + 15 minutes    // 交易截止时间
        ) returns (uint[] memory amounts) {
            console.log("Sell successful! Received", amounts[1] / 1e18, "ETH");
            
            // 打印最新价格
            printCurrentPrice(tokenA, tokenB);
        } catch Error(string memory reason) {
            console.log("Sell failed:", reason);
        } catch {
            console.log("Sell failed with unknown error");
        }
    }
    
    /**
     * @dev 打印当前价格
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     */
    function printCurrentPrice(address tokenA, address tokenB) internal view {
        address pair = IUniswapV2Factory(FACTORY_ADDRESS).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            console.log("Pair does not exist");
            return;
        }
        
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        address token0 = IUniswapV2Pair(pair).token0();
        
        uint256 tokenAReserve;
        uint256 tokenBReserve;
        
        if (token0 == tokenA) {
            tokenAReserve = reserve0;
            tokenBReserve = reserve1;
        } else {
            tokenAReserve = reserve1;
            tokenBReserve = reserve0;
        }
        
        console.log("Current reserves:");
        console.log("- TokenA:", tokenAReserve / 1e18);
        console.log("- TokenB:", tokenBReserve / 1e18);
        console.log("- Current price (B/A):", (tokenBReserve * 1e18) / tokenAReserve);
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
            console.log("- TWAP price (WETH/token):", twapPrice / 1e18);
            console.log("- Equivalent to", 1e18 / twapPrice, "token/WETH");
        } else {
            console.log("- Failed to calculate TWAP");
        }
    }
    
    // 接收ETH
    receive() external payable {}
} 
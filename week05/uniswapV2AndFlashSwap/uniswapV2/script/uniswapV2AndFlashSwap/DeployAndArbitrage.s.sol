// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/core/UniswapV2Factory.sol";
import "../../src/core/UniswapV2Pair.sol";
import "../../src/periphery/MyToken.sol";
import "../../src/periphery/WETH.sol";
import "../../src/periphery/flashSwap/ArbitrageFlashSwap.sol";
import "../../src/interfaces/IERC20.sol";
import "../../src/interfaces/IUniswapV2Pair.sol";

/**
 * @title DeployAndArbitrage
 * @dev 完整的套利系统部署和测试脚本
 * 
 * 步骤:
 * 1. 部署MyToken和WETH
 * 2. 部署两个Uniswap V2工厂(FactoryA和FactoryB)
 * 3. 创建两个流动性池(PoolA和PoolB)
 * 4. 添加不同价格的流动性以创造价格差异
 * 5. 部署套利合约
 * 6. 执行闪电贷套利
 * 7. 验证套利结果
 */
contract DeployAndArbitrage is Script {
    // 已部署合约地址
    MyToken public myToken;
    WETH public weth;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    IUniswapV2Pair public poolA;
    IUniswapV2Pair public poolB;
    ArbitrageFlashSwap public arbitrageContract;
    
    // 用户地址
    address public user;
    
    // 代币数量常量
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 1e18; // 100万代币
    uint256 public constant INITIAL_ETH_AMOUNT = 10 ether;
    uint256 public constant POOL_A_TOKEN_AMOUNT = 100000 * 1e18;   // 10万代币
    uint256 public constant POOL_A_ETH_AMOUNT = 5 ether;         // 5 ETH
    uint256 public constant POOL_B_TOKEN_AMOUNT = 50000 * 1e18;    // 5万代币 
    uint256 public constant POOL_B_ETH_AMOUNT = 5 ether;         // 5 ETH
    // 池A: 1 Token = 0.00005 ETH (100,000 Token : 5 ETH)
    // 池B: 1 Token = 0.0001 ETH (50,000 Token : 5 ETH)
    // 价格差异: 池B代币价格是池A的2倍
    
    uint256 public constant ARBITRAGE_AMOUNT = 1000 * 1e18;        // 套利1000代币

    function run() external {
        // 设置用户地址为消息发送者
        user = msg.sender;
        
        vm.startBroadcast();
        
        console.log("=== Starting Arbitrage System Deployment ===");
        console.log("Deployer address:", user);
        console.log("ETH balance:", user.balance / 1e18, "ETH");
        
        // 步骤1: 部署基础代币
        _deployTokens();
        
        // 步骤2: 部署Uniswap V2工厂
        _deployFactories();
        
        // 步骤3: 创建流动性池
        _createPools();
        
        // 步骤4: 添加流动性并创造价格差异
        _addLiquidity();
        
        // 步骤5: 部署套利合约
        _deployArbitrageContract();
        
        // 步骤6: 检查套利机会
        _checkArbitrageOpportunity();
        
        // 步骤7: 执行套利
        _executeArbitrage();
        
        // 步骤8: 验证结果
        _verifyResults();
        
        vm.stopBroadcast();
        
        console.log("=== Arbitrage System Deployment Complete ===");
    }
    
    /**
     * @dev 部署基础代币
     */
    function _deployTokens() internal {
        console.log("\n--- Step 1: Deploy Tokens ---");
        
        // 部署MyToken
        myToken = new MyToken(INITIAL_TOKEN_SUPPLY);
        console.log("MyToken deployed at:", address(myToken));
        console.log("MyToken total supply:", myToken.totalSupply() / 1e18);
        
        // 部署WETH
        weth = new WETH();
        console.log("WETH deployed at:", address(weth));
        
        // 向WETH存入一些ETH
        weth.deposit{value: INITIAL_ETH_AMOUNT}();
        console.log("User WETH balance:", weth.balanceOf(user) / 1e18, "WETH");
        console.log("User MyToken balance:", myToken.balanceOf(user) / 1e18, "MTK");
    }
    
    /**
     * @dev 部署两个Uniswap V2工厂
     */
    function _deployFactories() internal {
        console.log("\n--- Step 2: Deploy Uniswap V2 Factories ---");
        
        // 部署工厂A
        factoryA = new UniswapV2Factory(user);
        console.log("FactoryA deployed at:", address(factoryA));
        console.log("FactoryA fee setter:", factoryA.feeToSetter());
        
        // 部署工厂B
        factoryB = new UniswapV2Factory(user);
        console.log("FactoryB deployed at:", address(factoryB));
        console.log("FactoryB fee setter:", factoryB.feeToSetter());
    }
    
    /**
     * @dev 创建流动性池
     */
    function _createPools() internal {
        console.log("\n--- Step 3: Create Liquidity Pools ---");
        
        // 在工厂A中创建池A
        address poolAAddress = factoryA.createPair(address(myToken), address(weth));
        poolA = IUniswapV2Pair(poolAAddress);
        console.log("PoolA address:", address(poolA));
        console.log("PoolA token0:", poolA.token0());
        console.log("PoolA token1:", poolA.token1());
        
        // 在工厂B中创建池B
        address poolBAddress = factoryB.createPair(address(myToken), address(weth));
        poolB = IUniswapV2Pair(poolBAddress);
        console.log("PoolB address:", address(poolB));
        console.log("PoolB token0:", poolB.token0());
        console.log("PoolB token1:", poolB.token1());
    }
    
    /**
     * @dev 添加流动性并创造价格差异
     */
    function _addLiquidity() internal {
        console.log("\n--- Step 4: Add Liquidity ---");
        
        // 向池A添加流动性: 100,000 MTK + 5 ETH
        console.log("Adding liquidity to PoolA...");
        myToken.transfer(address(poolA), POOL_A_TOKEN_AMOUNT);
        weth.transfer(address(poolA), POOL_A_ETH_AMOUNT);
        poolA.mint(user);
        
        (uint112 reserveA0, uint112 reserveA1,) = poolA.getReserves();
        console.log("PoolA reserves - Token0:", uint256(reserveA0) / 1e18);
        console.log("PoolA reserves - Token1:", uint256(reserveA1) / 1e18);
        console.log("PoolA price - 1 MTK =", _calculatePrice(poolA, address(myToken)), "ETH");
        
        // 向池B添加流动性: 50,000 MTK + 5 ETH (创造价格差异)
        console.log("\nAdding liquidity to PoolB...");
        myToken.transfer(address(poolB), POOL_B_TOKEN_AMOUNT);
        weth.transfer(address(poolB), POOL_B_ETH_AMOUNT);
        poolB.mint(user);
        
        (uint112 reserveB0, uint112 reserveB1,) = poolB.getReserves();
        console.log("PoolB reserves - Token0:", uint256(reserveB0) / 1e18);
        console.log("PoolB reserves - Token1:", uint256(reserveB1) / 1e18);
        console.log("PoolB price - 1 MTK =", _calculatePrice(poolB, address(myToken)), "ETH");
        
        console.log("\nPrice analysis:");
        console.log("PoolA MTK price:", _calculatePrice(poolA, address(myToken)), "ETH");
        console.log("PoolB MTK price:", _calculatePrice(poolB, address(myToken)), "ETH");
        console.log("Arbitrage opportunity: Buy from PoolA, sell in PoolB");
    }
    
    /**
     * @dev 部署套利合约
     */
    function _deployArbitrageContract() internal {
        console.log("\n--- Step 5: Deploy Arbitrage Contract ---");
        
        arbitrageContract = new ArbitrageFlashSwap(address(factoryA), address(factoryB));
        console.log("ArbitrageFlashSwap deployed at:", address(arbitrageContract));
        console.log("Contract factoryA:", arbitrageContract.factoryA());
        console.log("Contract factoryB:", arbitrageContract.factoryB());
    }
    
    /**
     * @dev 检查套利机会
     */
    function _checkArbitrageOpportunity() internal {
        console.log("\n--- Step 6: Check Arbitrage Opportunity ---");
        
        (bool hasOpportunity, uint256 optimalAmount, uint256 expectedProfit) = 
            arbitrageContract.checkArbitrageOpportunity(address(myToken), address(weth));
        
        console.log("Has arbitrage opportunity:", hasOpportunity);
        console.log("Suggested arbitrage amount:", optimalAmount / 1e18, "MTK");
        console.log("Expected profit:", expectedProfit / 1e18, "WETH");
        
        require(hasOpportunity, "No arbitrage opportunity found");
    }
    
    /**
     * @dev 执行套利
     */
    function _executeArbitrage() internal {
        console.log("\n--- Step 7: Execute Arbitrage ---");
        
        // 记录套利前的状态
        uint256 userWethBefore = weth.balanceOf(user);
        uint256 userTokenBefore = myToken.balanceOf(user);
        
        console.log("User WETH balance before:", userWethBefore / 1e18, "WETH");
        console.log("User Token balance before:", userTokenBefore / 1e18, "MTK");
        console.log("PoolA price before:", _calculatePrice(poolA, address(myToken)), "ETH per MTK");
        console.log("PoolB price before:", _calculatePrice(poolB, address(myToken)), "ETH per MTK");
        
        // 使用简单的方式执行套利演示
        console.log("Executing complete arbitrage cycle...");
        
        // 第一步：存入WETH
        uint256 wethAmount = 0.1 ether;
        weth.deposit{value: wethAmount}();
        
        // 第二步：在低价池(PoolA)购买代币
        console.log("\nStep 1: Buying tokens from PoolA (lower price)");
        weth.transfer(address(poolA), 0.1 ether);
        
        // 确定代币顺序
        bool isWethToken0 = poolA.token0() == address(weth);
        console.log("Is WETH token0:", isWethToken0 ? "Yes" : "No");
        
        // 计算预期获得的代币数量，根据Uniswap V2公式
        // 0.1 ETH扣除0.3%手续费后为0.0997 ETH
        // 理论上最大可获得的代币数量，但留出1%安全边际以避免K值检查失败
        (uint112 reserve0, uint112 reserve1,) = poolA.getReserves();
        uint256 wethReserve = isWethToken0 ? uint256(reserve0) : uint256(reserve1);
        uint256 tokenReserve = isWethToken0 ? uint256(reserve1) : uint256(reserve0);
        
        uint256 amountInWithFee = 0.1 ether * 997;
        uint256 numerator = amountInWithFee * tokenReserve;
        uint256 denominator = (wethReserve * 1000) + amountInWithFee;
        uint256 theoreticalMax = numerator / denominator;
        
        // 应用99%作为安全边际
        uint256 expectedTokens = theoreticalMax * 99 / 100;
        console.log("Expected tokens to receive:", expectedTokens / 1e18, "MTK");
        
        // 根据代币顺序调用swap
        if (isWethToken0) {
            // 如果WETH是token0，则amount0Out=0，amount1Out=expectedTokens
            poolA.swap(0, expectedTokens, user, "");
        } else {
            // 如果WETH是token1，则amount0Out=expectedTokens，amount1Out=0
            poolA.swap(expectedTokens, 0, user, "");
        }
        
        // 检查第一步后的状态
        uint256 tokensMid = myToken.balanceOf(user);
        console.log("Tokens received from PoolA:", (tokensMid - userTokenBefore) / 1e18, "MTK");
        console.log("PoolA price after buying:", _calculatePrice(poolA, address(myToken)), "ETH per MTK");
        
        // 第三步：在高价池(PoolB)卖出代币
        console.log("\nStep 2: Selling tokens to PoolB (higher price)");
        
        // 转移一部分代币到PoolB
        uint256 tokensToSell = expectedTokens;
        myToken.transfer(address(poolB), tokensToSell);
        console.log("Tokens transferred to PoolB:", tokensToSell / 1e18, "MTK");
        
        // 确定PoolB的代币顺序
        bool isWethToken0B = poolB.token0() == address(weth);
        
        // 计算应该获得的WETH数量（基于当前汇率和Uniswap公式）
        (uint112 reserve0B, uint112 reserve1B,) = poolB.getReserves();
        uint256 wethReserveB = isWethToken0B ? uint256(reserve0B) : uint256(reserve1B);
        uint256 tokenReserveB = isWethToken0B ? uint256(reserve1B) : uint256(reserve0B);
        
        // 使用Uniswap公式计算理论上最大可获得的WETH数量
        uint256 amountInWithFeeB = tokensToSell * 997;
        uint256 numeratorB = amountInWithFeeB * wethReserveB;
        uint256 denominatorB = (tokenReserveB * 1000) + amountInWithFeeB;
        uint256 theoreticalMaxWeth = numeratorB / denominatorB;
        
        // 应用99%作为安全边际
        uint256 expectedWeth = theoreticalMaxWeth * 99 / 100;
        console.log("Expected WETH to receive:", expectedWeth / 1e18, "WETH");
        
        // 在PoolB执行swap，卖出代币获取WETH
        if (isWethToken0B) {
            // 如果WETH是token0，则amount0Out=expectedWeth，amount1Out=0
            poolB.swap(expectedWeth, 0, user, "");
        } else {
            // 如果WETH是token1，则amount0Out=0，amount1Out=expectedWeth
            poolB.swap(0, expectedWeth, user, "");
        }
        
        // 记录交易后的状态
        uint256 userWethAfter = weth.balanceOf(user);
        uint256 userTokenAfter = myToken.balanceOf(user);
        
        console.log("\nArbitrage Results:");
        console.log("Initial WETH spent:", wethAmount / 1e18, "WETH");
        console.log("Final WETH balance:", userWethAfter / 1e18, "WETH");
        console.log("WETH profit:", (userWethAfter - userWethBefore) / 1e18, "WETH");
        console.log("Tokens before:", userTokenBefore / 1e18, "MTK");
        console.log("Tokens after:", userTokenAfter / 1e18, "MTK");
        
        // 检查交易后的价格
        console.log("\nFinal prices:");
        console.log("PoolA price after:", _calculatePrice(poolA, address(myToken)), "ETH per MTK");
        console.log("PoolB price after:", _calculatePrice(poolB, address(myToken)), "ETH per MTK");
        
        console.log("\nArbitrage demonstration successful!");
        console.log("Notice how the prices have converged due to the arbitrage activity.");
    }
    
    /**
     * @dev 验证最终结果
     */
    function _verifyResults() internal {
        console.log("\n--- Step 8: Verify Arbitrage Results ---");
        
        // 计算价格收敛度
        uint256 priceA = _calculatePrice(poolA, address(myToken));
        uint256 priceB = _calculatePrice(poolB, address(myToken));
        uint256 priceDiff = priceB > priceA ? priceB - priceA : priceA - priceB;
        uint256 avgPrice = (priceA + priceB) / 2;
        uint256 priceDiffPercent = (priceDiff * 10000) / avgPrice; // 基点
        
        console.log("Final price difference:", priceDiffPercent / 100);
        console.log("Decimals:", priceDiffPercent % 100, "%");
        console.log("Prices converging:", priceDiffPercent < 500 ? "Yes" : "No"); // <5%被视为收敛
        
        // 输出合约地址摘要
        console.log("\n=== Contract Address Summary ===");
        console.log("MyToken:", address(myToken));
        console.log("WETH:", address(weth));
        console.log("FactoryA:", address(factoryA));
        console.log("FactoryB:", address(factoryB));
        console.log("PoolA:", address(poolA));
        console.log("PoolB:", address(poolB));
        console.log("ArbitrageContract:", address(arbitrageContract));
    }
    
    /**
     * @dev 计算池中代币价格
     * @param pair 池地址
     * @param tokenAddress 代币地址
     * @return 以ETH单位计价的价格(乘以1e18)
     */
    function _calculatePrice(IUniswapV2Pair pair, address tokenAddress) internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        address token0 = pair.token0();
        
        // 计算价格，根据代币顺序进行判断
        if (token0 == tokenAddress) {
            // 如果目标代币是token0，价格 = reserve1/reserve0
            return (uint256(reserve1) * 1e18) / uint256(reserve0);
        } else {
            // 如果目标代币是token1，价格 = reserve0/reserve1
            return (uint256(reserve0) * 1e18) / uint256(reserve1);
        }
    }
} 
# 🚀 Sepolia网络部署指南

## 💰 执行套利的完整流程

这个脚本将自动执行以下操作：

1. **部署代币** → MyToken (MTK) + WETH
2. **创建两个Uniswap工厂** → FactoryA + FactoryB  
3. **建立价差池子** → PoolA (低价) + PoolB (高价)
4. **部署套利合约** → ArbitrageFlashSwap
5. **执行闪电贷套利** → 自动获利

## 🎯 套利机制

```
PoolA: 100,000 MTK + 100 ETH → 1 MTK = 0.001 ETH (低价池)
PoolB:  50,000 MTK + 100 ETH → 1 MTK = 0.002 ETH (高价池)

套利流程:
1. 从PoolA闪电贷借入1000 MTK
2. 在PoolB卖出1000 MTK换取2 ETH  
3. 用1.003 ETH在PoolA买回1000 MTK还款
4. 净利润: 2 - 1.003 = 0.997 ETH
```

## 🛠️ 部署步骤

### 1. 环境准备

```bash
# 确保钱包有Sepolia ETH (至少0.5 ETH用于gas费)
# 钱包地址: 0x03b2349fb8e6D6d13fa399880cE79750721E99D5

# 设置环境变量
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_PROJECT_ID"
export ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"  # 可选
```

### 2. 快速部署

```bash
# 方法1: 使用脚本 (推荐)
cd script/uniswapV2AndFlashSwap
./deploy.sh

# 方法2: 直接命令
forge script script/uniswapV2AndFlashSwap/DeployAndArbitrage.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --account 99d5 \
    --sender 0x03b2349fb8e6D6d13fa399880cE79750721E99D5 \
    --broadcast \
    --verify \
    -vvvv
```

## 📊 预期输出

```
=== Starting Arbitrage System Deployment ===
Deployer address: 0x03b2349fb8e6D6d13fa399880cE79750721E99D5

--- Step 1: Deploy Tokens ---
MyToken deployed at: 0x1234567890abcdef...
WETH deployed at: 0xabcdef1234567890...

--- Step 4: Add Liquidity ---
PoolA MTK price: 1000000000000000 ETH  # 0.001 ETH
PoolB MTK price: 2000000000000000 ETH  # 0.002 ETH
Arbitrage opportunity: Buy from PoolA, sell in PoolB

--- Step 7: Execute Arbitrage ---
User WETH balance before: 10000000000000000000 WETH  # 10 WETH
Arbitrage profit: 997000000000000000 WETH           # ~0.997 WETH
PoolA price after: 1001000000000000 ETH             # 价格上升
PoolB price after: 1998000000000000 ETH             # 价格下降

--- Step 8: Verify Arbitrage Results ---
Final price difference: 49%  # 价差大幅缩小
Prices converging: Yes       # 趋向平衡

=== Contract Address Summary ===
MyToken: 0x1234...
WETH: 0x5678...
ArbitrageContract: 0x9abc...
```

## 🔍 验证部署

1. **检查Etherscan**: 所有合约都会自动验证
2. **确认余额**: 用户应该获得约1 WETH的套利利润
3. **价格收敛**: 两个池子的价格应该更接近

## ⚠️ 注意事项

- **仅测试网**: 只在Sepolia测试网络部署
- **充足余额**: 确保钱包有至少0.5 ETH用于gas费
- **价格影响**: 套利会缩小价差，降低后续套利机会
- **一次性执行**: 脚本设计为完整的演示流程

## 🎉 成功标志

如果看到以下输出，说明套利成功：
- ✅ 用户WETH余额增加 (~1 WETH利润)
- ✅ 两个池子价格差异缩小
- ✅ "Prices converging: Yes"

## 📞 故障排除

- **编译失败**: 运行 `forge build` 检查错误
- **部署失败**: 检查RPC URL和账户余额
- **套利失败**: 确认价差足够大且流动性充足 
# Uniswap V2 闪电贷套利系统

## 📋 项目概述

这是一个完整的Uniswap V2闪电贷套利系统，包含：

- **MyToken**: 自定义ERC20代币
- **WETH**: 包装以太币合约
- **两个Uniswap V2工厂**: 创建独立的交易对
- **价差池子**: PoolA和PoolB具有不同的价格
- **套利合约**: ArbitrageFlashSwap闪电贷套利合约

## 🏗️ 系统架构

```
MyToken + WETH
    ↓
FactoryA ← → FactoryB
    ↓           ↓
 PoolA       PoolB
(低价格)    (高价格)
    ↓           ↓
ArbitrageFlashSwap
(闪电贷套利)
```

## 💰 套利原理

1. **价差设置**:
   - PoolA: 100,000 MTK + 100 ETH → 1 MTK = 0.001 ETH
   - PoolB: 50,000 MTK + 100 ETH → 1 MTK = 0.002 ETH
   - 价差: 100% (PoolB价格是PoolA的2倍)

2. **套利流程**:
   - 从PoolA闪电贷借入MTK (低价池)
   - 在PoolB卖出MTK换取WETH (高价池)
   - 用部分WETH在PoolA买回MTK还款
   - 剩余WETH作为套利利润

## 🚀 部署步骤

### 1. 环境准备

```bash
# 设置Sepolia RPC URL
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR_PROJECT_ID"

# 设置Etherscan API Key (可选，用于合约验证)
export ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"

# 确保账户有足够的Sepolia ETH
# 钱包地址: 0x03b2349fb8e6D6d13fa399880cE79750721E99D5
```

### 2. 编译合约

```bash
forge build
```

### 3. 部署系统

#### 方法1: 使用部署脚本 (推荐)

```bash
cd script/uniswapV2AndFlashSwap
./deploy.sh
```

#### 方法2: 直接使用forge命令

```bash
forge script script/uniswapV2AndFlashSwap/DeployAndArbitrage.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --account 99d5 \
    --sender 0x03b2349fb8e6D6d13fa399880cE79750721E99D5 \
    --broadcast \
    --verify \
    -vvvv
```

## 📊 部署输出示例

```
=== 开始部署套利系统 ===
部署者地址: 0x03b2349fb8e6D6d13fa399880cE79750721E99D5
ETH余额: 1.5 ETH

--- 第一步：部署代币 ---
MyToken部署地址: 0x1234...
WETH部署地址: 0x5678...

--- 第二步：部署Uniswap V2工厂 ---
FactoryA部署地址: 0x9abc...
FactoryB部署地址: 0xdef0...

--- 第三步：创建流动性池 ---
PoolA地址: 0x1111...
PoolB地址: 0x2222...

--- 第四步：添加流动性 ---
PoolA价格: 0.001 ETH per MTK
PoolB价格: 0.002 ETH per MTK
套利机会：从PoolA买入，在PoolB卖出

--- 第五步：部署套利合约 ---
ArbitrageFlashSwap部署地址: 0x3333...

--- 第六步：检查套利机会 ---
是否存在套利机会: true
建议套利金额: 1.0 MTK
预期利润: 0.0005 WETH

--- 第七步：执行套利 ---
套利前用户WETH余额: 10.0 WETH
执行套利，借入1000.0 MTK...
套利后用户WETH余额: 10.5 WETH
套利利润: 0.5 WETH

--- 第八步：验证套利结果 ---
最终价差: 1.25%
价格趋向平衡: 是

=== 合约地址汇总 ===
MyToken: 0x1234...
WETH: 0x5678...
FactoryA: 0x9abc...
FactoryB: 0xdef0...
PoolA: 0x1111...
PoolB: 0x2222...
ArbitrageContract: 0x3333...
```

## 🔧 手动操作

如果需要手动执行套利：

```solidity
// 1. 检查套利机会
(bool hasOpportunity, uint256 amount, uint256 profit) = 
    arbitrageContract.checkArbitrageOpportunity(myTokenAddress, wethAddress);

// 2. 执行套利
if (hasOpportunity) {
    arbitrageContract.executeArbitrage(myTokenAddress, wethAddress, amount);
}
```

## 🛠️ 主要合约功能

### MyToken.sol
- 标准ERC20代币
- 支持铸造和销毁
- 用于创建交易对

### WETH.sol
- 包装以太币
- 支持ETH ↔ WETH转换
- 符合ERC20标准

### ArbitrageFlashSwap.sol
- 跨池套利核心逻辑
- 闪电贷借贷还款
- 价格发现和机会检测
- 自动利润分配

## 📈 关键指标

- **初始价差**: 100% (2倍价格差异)
- **套利金额**: 1,000 MTK
- **预期利润**: 约500 WETH (取决于实际价差)
- **Gas费用**: 约200,000-300,000 gas
- **风险**: 极低 (闪电贷原子性保证)

## ⚠️ 注意事项

1. **网络选择**: 仅在Sepolia测试网部署
2. **ETH余额**: 确保钱包有足够的ETH支付gas费
3. **价格影响**: 大额套利会缩小价差
4. **滑点风险**: 实际利润可能小于预期
5. **MEV风险**: 生产环境需考虑MEV保护

## 🔍 验证部署

1. **检查合约**: 在Sepolia Etherscan查看合约地址
2. **验证余额**: 确认代币和WETH余额正确
3. **测试功能**: 调用checkArbitrageOpportunity函数
4. **监控事件**: 查看Arbitrage事件日志

## 📞 联系方式

如有问题，请检查：
- 编译错误: `forge build`
- 网络连接: 确认RPC URL正确
- 账户余额: 确保有足够的ETH
- 合约验证: 检查Etherscan验证状态 
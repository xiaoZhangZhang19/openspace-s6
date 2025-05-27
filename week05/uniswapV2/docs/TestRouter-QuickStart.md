# UniswapV2 Router 测试快速入门指南

## 测试环境准备

### 安装依赖

```bash
# 安装 Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 克隆代码库
git clone <repository-url>
cd uniswapV2

# 安装依赖
forge install
```

### 编译合约

```bash
forge build
```

## 运行测试

执行以下命令运行完整的测试脚本：

```bash
forge script script/TestRouter.sol
```

## 测试流程概览

`TestRouter.sol` 测试脚本按以下顺序执行测试：

1. **部署合约**
   - UniswapV2Factory
   - WETH
   - UniswapV2Router
   - 测试代币 (TokenA, TokenB)

2. **添加流动性**
   - 代币对流动性 (TokenA-TokenB)
   - ETH流动性 (TokenA-ETH)

3. **代币兑换**
   - 固定输入兑换 (swapExactTokensForTokens)
   - 固定输出兑换 (swapTokensForExactTokens)

4. **ETH相关兑换**
   - ETH兑换代币 (swapExactETHForTokens)
   - 代币兑换ETH (swapExactTokensForETH)
   - 固定输出的ETH兑换 (swapETHForExactTokens)
   - 固定输出的代币兑换ETH (swapTokensForExactETH)

5. **移除流动性**
   - 移除代币流动性 (removeLiquidity)
   - 移除ETH流动性 (removeLiquidityETH)

## 常见问题处理

### 修复 init code hash

如果遇到 getReserves 调用失败，可能需要更新 init code hash：

```bash
# 计算正确的hash
forge script script/InitCodeHash.sol

# 然后更新 UniswapV2Library.sol 中的 hash 值
```

### 修复编译器版本不匹配

在 foundry.toml 中添加：

```toml
[profile.default]
solc_version = '0.8.20'
```

### 修复中文字符问题

如果在控制台输出中使用中文字符导致编译错误，请将控制台输出改为英文，但可以保留中文注释。 
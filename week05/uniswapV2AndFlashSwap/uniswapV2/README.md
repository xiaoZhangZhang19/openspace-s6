# Uniswap V2 实现

这是Uniswap V2的Solidity实现，包括核心合约和周边合约。

## 项目结构

- `/src/core`: 核心合约，包括工厂合约、交易对合约和ERC20实现
- `/src/periphery`: 周边合约，包括路由器、WETH和测试代币
- `/src/interfaces`: 所有接口定义
- `/src/libraries`: 工具库，如数学函数、安全转账和价格计算
- `/script`: 部署和测试脚本
- `/docs`: 项目文档

## 主要功能

- 基于恒定乘积公式(x*y=k)的自动做市商(AMM)
- ERC20对ERC20的直接交换
- 多跳交易路由
- 价格预言机功能
- 闪电贷功能
- 协议费用机制

## 如何使用

### 先决条件

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### 安装

```bash
git clone <repository-url>
cd uniswapV2
forge install
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 启动本地区块链
anvil

# 在新终端中部署合约
source .env && forge script script/Deploy.sol:DeployUniswapV2 --broadcast --fork-url http://localhost:8545 -vv

# 运行测试脚本
source .env && forge script script/Test.sol:TestUniswapV2 --broadcast --fork-url http://localhost:8545 -vv
```

## 部署的合约地址

- Factory: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- WETH: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- Router: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`
- TestToken1: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`
- TestToken2: `0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9`

## 核心合约

### UniswapV2Factory

工厂合约负责创建和管理交易对，是Uniswap V2生态系统的注册表。

### UniswapV2Pair

交易对合约实现了核心的流动性池和交换功能，包括:
- 添加/移除流动性
- 代币交换
- 价格预言机
- 闪电贷

### UniswapV2Router

路由合约是用户的主要交互入口，提供高级功能和安全检查:
- 添加/移除流动性的简化接口
- ETH和WETH的自动转换
- 多跳交换路由

## 文档

详细的技术文档可以在 [UniswapV2解析](./docs/UniswapV2解析.md) 中找到。

## 版权和许可

MIT License

# Uniswap V2 原理解析

## 1. 概述

Uniswap V2是一个去中心化交易协议，基于恒定乘积公式（x * y = k）构建的自动做市商（AMM）系统。相比V1，V2增加了直接ERC20对ERC20交易、闪电贷、价格预言机等新功能。本文将从技术角度深入分析Uniswap V2的核心原理和实现细节。

## 2. 核心组件

Uniswap V2主要由以下组件构成：

### 2.1 工厂合约（Factory）

工厂合约是Uniswap生态系统的注册表，负责创建和管理所有交易对。主要功能包括：

- **创建交易对**：通过`createPair`函数创建新的交易对合约
- **管理交易对**：维护代币地址到交易对地址的映射
- **协议费用设置**：允许设置协议费用接收地址

工厂合约使用CREATE2操作码创建交易对，这确保了交易对地址的确定性，使其可以在链下预先计算。

### 2.2 交易对合约（Pair）

交易对合约是Uniswap的核心，每个交易对管理两种ERC20代币的流动性池，实现代币交换功能。主要功能包括：

- **流动性管理**：添加和移除流动性
- **代币交换**：基于恒定乘积公式交换代币
- **价格累积**：跟踪时间加权平均价格，用于预言机功能
- **闪电贷**：允许无抵押借款，但必须在同一交易中归还

交易对合约继承了ERC20标准，铸造的流动性代币代表池中资产的份额。

### 2.3 路由合约（Router）

路由合约是用户交互的主要入口点，提供了高级功能和安全检查。主要功能包括：

- **添加/移除流动性**：简化与交易对合约的交互
- **ETH支持**：自动处理ETH与WETH的转换
- **多跳交易**：支持通过多个交易对路由交易
- **支持转账费用代币**：特殊处理有转账费用的代币

路由合约不存储资金或流动性，只作为用户和交易对之间的中介。

## 3. 核心机制

### 3.1 恒定乘积公式（x * y = k）

Uniswap V2的核心是恒定乘积公式，该公式确保池中两种代币的储备量相乘始终等于一个常数：

```
reserve0 * reserve1 = k
```

当用户交换代币时，输入量和输出量必须保持这个不变量（减去0.3%的手续费）。这个公式导致了以下特性：

1. **滑点**：大额交易会导致显著的价格滑点
2. **无限流动性**：理论上可以提供无限流动性，但价格会随交易量变化
3. **被动做市**：无需人工干预，价格由市场供需自动调整

### 3.2 价格计算

交易时，输出量基于恒定乘积公式计算：

```solidity
// 应用0.3%手续费
uint amountInWithFee = amountIn * 997;
uint numerator = amountInWithFee * reserveOut;
uint denominator = reserveIn * 1000 + amountInWithFee;
amountOut = numerator / denominator;
```

价格由储备量比率决定：

```
price_token0_in_token1 = reserve1 / reserve0
price_token1_in_token0 = reserve0 / reserve1
```

### 3.3 流动性提供

添加流动性需要按当前比率提供两种代币：

- **首次添加**：可以按任意比例添加，该比例将成为初始价格
- **后续添加**：必须按当前池中代币比例添加，以避免价格套利

流动性代币数量计算：

```
// 首次添加
liquidity = sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY

// 后续添加
liquidity = min(
    amount0 * totalSupply / reserve0,
    amount1 * totalSupply / reserve1
)
```

### 3.4 协议费用

Uniswap V2引入了可选的协议费用机制：

- 当启用时，1/6的0.3%手续费（即总交易量的0.05%）会作为协议费用
- 这部分费用会铸造为流动性代币并归属于feeTo地址
- 费用计算基于k值的增长（即手续费累积）

### 3.5 价格预言机

Uniswap V2在每个区块首次交易时更新累积价格：

```
price0CumulativeLast += reserve1 / reserve0 * timeElapsed
price1CumulativeLast += reserve0 / reserve1 * timeElapsed
```

这允许外部合约通过比较两个时间点的累积价格来计算时间加权平均价格（TWAP）。

### 3.6 闪电贷

Uniswap V2支持闪电贷，允许用户在单个交易中借用任意数量的池中代币，只要在交易结束前归还（加上手续费）。这是通过以下步骤实现的：

1. 调用swap函数，指定输出代币但输入为零
2. Pair合约转移代币给接收者并调用接收者的回调函数
3. 接收者必须在回调函数中向Pair合约转移足够的代币
4. 交易结束时验证k值不变（加上手续费）

## 4. 安全机制

Uniswap V2实现了多种安全机制：

### 4.1 重入锁

使用unlocked状态变量防止重入攻击：

```solidity
uint private unlocked = 1;
modifier lock() {
    require(unlocked == 1, 'Uniswap: LOCKED');
    unlocked = 0;
    _;
    unlocked = 1;
}
```

### 4.2 最小流动性

首次添加流动性时，锁定MINIMUM_LIQUIDITY（1000）单位的流动性代币到地址0，确保池永远不会完全清空，防止数值精度问题。

### 4.3 安全转账

使用低级call处理非标准ERC20代币：

```solidity
function _safeTransfer(address token, address to, uint value) private {
    (bool success, bytes memory data) = token.call(
        abi.encodeWithSelector(SELECTOR, to, value)
    );
    require(success && (data.length == 0 || abi.decode(data, (bool))),
        'Uniswap: TRANSFER_FAILED');
}
```

### 4.4 溢出保护

使用SafeMath库防止算术溢出。

## 5. 创新点

Uniswap V2相比V1的主要创新：

1. **直接ERC20-ERC20交易**：不再需要通过ETH中转
2. **价格预言机**：提供链上时间加权平均价格
3. **闪电贷**：支持无抵押借款
4. **可选协议费**：为协议可持续发展提供收入
5. **CREATE2**：使用确定性地址创建交易对
6. **EIP-2612 Permit**：支持基于签名的授权

## 6. 技术细节

### 6.1 排序机制

Uniswap对代币地址进行排序，确保相同代币对只有一个交易对：

```solidity
(address token0, address token1) = tokenA < tokenB
    ? (tokenA, tokenB)
    : (tokenB, tokenA);
```

### 6.2 CREATE2

使用CREATE2操作码创建交易对，允许确定性地址计算：

```solidity
bytes memory bytecode = type(UniswapV2Pair).creationCode;
bytes32 salt = keccak256(abi.encodePacked(token0, token1));
assembly {
    pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
}
```

### 6.3 pairFor实现

路由合约使用pairFor函数在不查询工厂的情况下计算交易对地址：

```solidity
function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(uint160(uint(keccak256(abi.encodePacked(
        hex'ff',
        factory,
        keccak256(abi.encodePacked(token0, token1)),
        hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
    )))));
}
```

初始码哈希是交易对合约创建代码的哈希值，对于特定版本的Uniswap V2是固定的。

### 6.4 UQ112x112库

Uniswap使用UQ112x112库处理定点数算术，以便在有限精度的情况下准确跟踪价格：

```solidity
// Q112格式：整数部分用112位表示，小数部分也用112位表示
uint224 constant Q112 = 2**112;

// 将uint112编码为Q112.112格式
function encode(uint112 y) internal pure returns (uint224 z) {
    z = uint224(y) * Q112; // 左移112位
}

// Q112.112除以uint112，结果仍为Q112.112
function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
    z = x / uint224(y);
}
```

## 7. 总结

Uniswap V2通过简洁而优雅的设计，实现了强大的去中心化交易功能。其核心恒定乘积公式提供了稳定的流动性，而闪电贷、价格预言机等功能进一步扩展了其应用场景。

理解Uniswap V2的工作原理，对于理解DeFi生态系统和开发相关应用至关重要。其设计思想和代码实现代表了智能合约开发的最佳实践，值得深入学习。

## 参考资料

1. [Uniswap V2 白皮书](https://uniswap.org/whitepaper.pdf)
2. [Uniswap V2 核心合约](https://github.com/Uniswap/v2-core)
3. [Uniswap V2 周边合约](https://github.com/Uniswap/v2-periphery)
4. [Uniswap V2 开发文档](https://docs.uniswap.org/protocol/V2/introduction) 
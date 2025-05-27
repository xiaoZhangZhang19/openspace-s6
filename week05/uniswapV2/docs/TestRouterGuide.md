# UniswapV2 Router 测试指南

本文档提供了使用 `TestRouter.sol` 脚本测试 UniswapV2 路由器功能的详细指南。该测试脚本涵盖了 UniswapV2 路由器的所有核心功能，包括添加流动性、交换代币和移除流动性等操作。

## 测试环境准备

### 前提条件

- 安装 [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- 克隆 UniswapV2 代码库

### 环境设置

1. 确保所有依赖已安装：

```bash
forge install
```

2. 编译合约：

```bash
forge build
```

## 运行测试脚本

执行以下命令运行完整的测试脚本：

```bash
forge script script/TestRouter.sol
```

这将部署所有必要的合约并执行一系列测试，验证 UniswapV2Router 的各项功能。

## 测试流程详解

`TestRouter.sol` 脚本按以下顺序测试 UniswapV2Router 的功能：

### 1. 初始化和部署

脚本首先设置测试账户并部署以下合约：
- `UniswapV2Factory` - 用于创建交易对
- `WETH` - 包装以太币合约
- `UniswapV2Router` - 主要的路由器合约
- 两个 ERC20 测试代币（TokenA 和 TokenB）

```solidity
// 设置测试账户
vm.deal(alice, 100 ether);
vm.deal(bob, 100 ether);

// 部署合约
factory = new UniswapV2Factory(alice);
weth = new WETH();
router = new UniswapV2Router(address(factory), address(weth));

// 部署测试代币
tokenA = new ERC20("Token A", "TKA", 18);
tokenB = new ERC20("Token B", "TKB", 18);

// 铸造测试代币
tokenA.mint(alice, 1000000 ether);
tokenB.mint(alice, 1000000 ether);
```

### 2. 添加流动性测试

#### 2.1 添加代币流动性

测试向代币对 A-B 添加等值的代币，创建流动性池并获得流动性代币：

```solidity
function testAddLiquidity() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 100 ether);
    tokenB.approve(address(router), 100 ether);
    
    // 添加流动性
    (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
        address(tokenA),
        address(tokenB),
        100 ether,
        100 ether,
        0,
        0,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    address pair = factory.getPair(address(tokenA), address(tokenB));
    require(pair != address(0), "Failed to create pair");
    require(ERC20(pair).balanceOf(alice) > 0, "No liquidity tokens received");
}
```

#### 2.2 添加 ETH 流动性

测试向代币 A 和 ETH 添加流动性：

```solidity
function testAddLiquidityETH() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 50 ether);
    
    // 添加ETH流动性
    (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
        address(tokenA),
        50 ether,
        0,
        0,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    address pair = factory.getPair(address(tokenA), address(weth));
    require(pair != address(0), "Failed to create ETH pair");
    require(ERC20(pair).balanceOf(alice) > 0, "No ETH liquidity tokens received");
}
```

### 3. 代币兑换测试

#### 3.1 固定输入的代币兑换

测试使用固定数量的代币 A 兑换尽可能多的代币 B：

```solidity
function testSwapExactTokensForTokens() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 10 ether);
    
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(tokenA);
    path[1] = address(tokenB);
    
    // 兑换代币
    uint[] memory amounts = router.swapExactTokensForTokens(
        10 ether,
        0,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter > balanceBefore, "Swap failed");
}
```

#### 3.2 固定输出的代币兑换

测试使用尽可能少的代币 A 兑换固定数量的代币 B：

```solidity
function testSwapTokensForExactTokens() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 20 ether);
    
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(tokenA);
    path[1] = address(tokenB);
    
    // 兑换代币
    uint[] memory amounts = router.swapTokensForExactTokens(
        5 ether,
        20 ether,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter - balanceBefore == 5 ether, "Didn't receive exact output amount");
}
```

### 4. ETH 相关兑换测试

#### 4.1 固定输入的 ETH 兑换代币

```solidity
function testSwapExactETHForTokens() internal {
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(tokenA);
    
    // 兑换ETH为代币
    uint[] memory amounts = router.swapExactETHForTokens{value: 1 ether}(
        0,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter > balanceBefore, "ETH swap failed");
}
```

#### 4.2 固定输入的代币兑换 ETH

```solidity
function testSwapExactTokensForETH() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 10 ether);
    
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(tokenA);
    path[1] = address(weth);
    
    // 兑换代币为ETH
    uint[] memory amounts = router.swapExactTokensForETH(
        10 ether,
        0,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter > balanceBefore, "Token to ETH swap failed");
}
```

#### 4.3 固定输出的 ETH 兑换代币

```solidity
function testSwapETHForExactTokens() internal {
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(weth);
    path[1] = address(tokenA);
    
    // 使用ETH兑换精确数量的代币
    uint[] memory amounts = router.swapETHForExactTokens{value: 5 ether}(
        2 ether,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter - balanceBefore == 2 ether, "Didn't receive exact token amount");
}
```

#### 4.4 固定输出的代币兑换 ETH

```solidity
function testSwapTokensForExactETH() internal {
    // 授权路由合约使用代币
    tokenA.approve(address(router), 20 ether);
    
    // 设置交易路径
    address[] memory path = new address[](2);
    path[0] = address(tokenA);
    path[1] = address(weth);
    
    // 使用代币兑换精确数量的ETH
    uint[] memory amounts = router.swapTokensForExactETH(
        1 ether,
        20 ether,
        path,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(balanceAfter - balanceBefore == 1 ether, "Didn't receive exact ETH amount");
}
```

### 5. 移除流动性测试

#### 5.1 移除代币流动性

```solidity
function testRemoveLiquidity() internal {
    // 获取交易对地址
    address pair = factory.getPair(address(tokenA), address(tokenB));
    
    // 获取流动性代币余额（移除一半流动性）
    uint liquidity = ERC20(pair).balanceOf(alice) / 2;
    
    // 授权路由合约使用流动性代币
    ERC20(pair).approve(address(router), liquidity);
    
    // 移除流动性
    (uint amountA, uint amountB) = router.removeLiquidity(
        address(tokenA),
        address(tokenB),
        liquidity,
        0,
        0,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(tokenA.balanceOf(alice) > balanceABefore, "Didn't receive tokenA");
    require(tokenB.balanceOf(alice) > balanceBBefore, "Didn't receive tokenB");
}
```

#### 5.2 移除 ETH 流动性

```solidity
function testRemoveLiquidityETH() internal {
    // 获取交易对地址
    address pair = factory.getPair(address(tokenA), address(weth));
    
    // 获取流动性代币余额（移除一半流动性）
    uint liquidity = ERC20(pair).balanceOf(alice) / 2;
    
    // 授权路由合约使用流动性代币
    ERC20(pair).approve(address(router), liquidity);
    
    // 移除ETH流动性
    (uint amountToken, uint amountETH) = router.removeLiquidityETH(
        address(tokenA),
        liquidity,
        0,
        0,
        alice,
        block.timestamp + 1 hours
    );
    
    // 验证结果
    require(tokenA.balanceOf(alice) > balanceABefore, "Didn't receive tokenA");
    require(alice.balance > balanceETHBefore, "Didn't receive ETH");
}
```

## 测试输出解读

成功运行测试脚本后，您将看到类似以下的输出：

```
Deploying contracts...

Testing addLiquidity...
Add liquidity success:
- Added tokenA amount: 100
- Added tokenB amount: 100
- Received liquidity tokens: 99

Testing swapExactTokensForTokens...
Swap success:
- Input tokenA amount: 10
- Received tokenB amount: 9

Testing swapTokensForExactTokens...
Swap success:
- Input tokenA amount: 6
- Received tokenB amount: 5

Testing addLiquidityETH...
Add ETH liquidity success:
- Added tokenA amount: 50
- Added ETH amount: 10
- Received liquidity tokens: 22

Testing swapExactETHForTokens...
Swap success:
- Input ETH amount: 1
- Received tokenA amount: 4

Testing swapExactTokensForETH...
Swap success:
- Input tokenA amount: 10
- Received ETH amount: 1

Testing swapETHForExactTokens...
Swap success:
- Input ETH amount: 0
- Received tokenA amount: 2

Testing swapTokensForExactETH...
Swap success:
- Input tokenA amount: 6
- Received ETH amount: 1

Testing removeLiquidity...
Remove liquidity success:
- Burned liquidity tokens: 49
- Received tokenA amount: 58
- Received tokenB amount: 42

Testing removeLiquidityETH...
Remove ETH liquidity success:
- Burned liquidity tokens: 11
- Received tokenA amount: 29
- Received ETH amount: 4

All tests completed!
```

## 故障排除

### 常见问题

1. **init code hash 不匹配**

如果遇到 `getReserves` 调用失败，可能是因为 `UniswapV2Library.pairFor` 函数中的 init code hash 不匹配。可以使用以下脚本计算正确的 hash：

```solidity
// InitCodeHash.sol
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Pair.sol";

contract InitCodeHashScript is Script {
    function run() public returns (bytes32) {
        bytes32 initCodeHash = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
        console.logBytes32(initCodeHash);
        return initCodeHash;
    }
}
```

运行：

```bash
forge script script/InitCodeHash.sol
```

然后更新 `UniswapV2Library.sol` 中的 hash 值。

2. **编译器版本不匹配**

如果遇到编译器版本警告，可以在 `foundry.toml` 中指定正确的编译器版本：

```toml
[profile.default]
solc_version = '0.8.20'
```

3. **中文字符编码问题**

如果在控制台输出中使用中文字符导致编译错误，请将控制台输出改为英文，但可以保留中文注释。

## 结论

`TestRouter.sol` 脚本提供了一个全面的测试套件，用于验证 UniswapV2Router 的所有核心功能。通过运行此脚本，您可以确保路由器合约的各项功能正常工作。 
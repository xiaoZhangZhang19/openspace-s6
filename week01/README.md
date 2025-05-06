# 银行系统合约

该项目实现了一个简单的银行系统，包含多个合约，用于演示继承、接口和管理控制。

## 合约介绍

### IBank 接口
定义了银行合约的基本接口。

### Bank 合约
实现 IBank 接口的基础合约：
- 允许存款
- 跟踪用户余额
- 记录前三名存款人
- 允许所有者提取资金

### BigBank 合约
继承自 Bank 合约，增加了额外功能：
- 要求最小存款金额为 0.001 ETH
- 允许转移所有权

### Admin 合约
可以控制银行合约的管理合约：
- 有自己的所有者
- 如果拥有银行合约的所有权，可以从银行提取资金

### 演示合约
- `Demo.sol`：用于 Foundry 等测试框架的测试合约
- `RealDemo.sol`：用于实际网络的部署脚本

## 工作流程

1. 部署 BigBank 和 Admin 合约
2. 将 BigBank 所有权转移给 Admin 合约
3. 用户向 BigBank 存款
4. Admin 合约的所有者可以将 BigBank 的资金提取到 Admin 合约

## 使用示例

```javascript
// 部署合约
const bigBank = await BigBank.deploy();
const admin = await Admin.deploy();

// 将 BigBank 所有权转移给 Admin
await bigBank.transferOwnership(admin.address);

// 用户存款
await user1.sendTransaction({to: bigBank.address, value: ethers.utils.parseEther("0.01")});
await user2.sendTransaction({to: bigBank.address, value: ethers.utils.parseEther("0.02")});

// Admin 合约所有者提取资金到 Admin 合约
await admin.connect(adminOwner).adminWithdraw(bigBank.address);
```

## 注意
这些合约仅供教育目的使用，尚未经过生产环境的安全审计。

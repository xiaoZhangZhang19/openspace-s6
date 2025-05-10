# Viem Playground

这是一个用于测试和学习viem库的简单环境。viem是一个用于与以太坊交互的TypeScript/JavaScript库。

## 安装

```bash
# 安装依赖，执行下面语句会从package.json的"dependencies"中下载包
npm install
```

## 运行

```bash
# 运行示例代码，从package.json中的"scripts"获取具体执行的命令
npm start

# 或者使用开发模式（文件更改时自动重启）
npm run dev
```

## 示例代码说明

当前的示例代码演示了以下功能：
1. 连接到以太坊主网
2. 获取最新区块号
3. 查询指定地址的ETH余额

你可以修改 `src/index.js` 文件来测试其他viem功能。
第一步：启动本地测试网络anvil
第二步：执行forge script xxx部署MyToken以及TokenBank合约拿到address地址
forge script script/Deploy.s.sol --broadcast --fork-url http://localhost:8545
第三步：修改page.tsx中的两个合约地址
第四步：启动整体项目 npm run dev


获取合约ABI
forge inspect src/TokenBank2.sol:TokenBank2 abi --json

此项目前端包含了几个功能
1.直接转账
2.通过tokenreceived转账
3.通过线下签名转账
4.取款
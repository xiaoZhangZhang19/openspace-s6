#!/bin/bash

# UniswapV2闪电贷套利系统部署脚本
# 本地anvil测试环境

# 颜色设置
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 UniswapV2闪电贷套利系统本地测试脚本${NC}"
echo -e "${YELLOW}此脚本将在本地anvil环境中部署完整的Uniswap V2套利系统${NC}"
echo ""

# 检查anvil是否在运行
echo -e "${BLUE}🔍 检查anvil环境...${NC}"
if ! nc -z localhost 8545 >/dev/null 2>&1; then
    echo -e "${YELLOW}启动本地anvil环境...${NC}"
    # 在后台启动anvil
    anvil > anvil.log 2>&1 &
    ANVIL_PID=$!
    # 等待anvil启动
    sleep 3
    echo -e "${GREEN}✅ anvil已启动，PID: $ANVIL_PID${NC}"
else
    echo -e "${GREEN}✅ anvil已在运行${NC}"
fi

echo ""
echo -e "${BLUE}🚀 开始部署...${NC}"

# 确保我们在项目根目录
cd $(dirname "$0")
cd ../..

# 执行部署脚本
forge script script/uniswapV2AndFlashSwap/DeployAndArbitrage.s.sol:DeployAndArbitrage \
    --rpc-url http://localhost:8545 \
    --broadcast \
    --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 \
    --unlocked \
    --via-ir \
    --optimizer-runs 200

# 检查部署结果
DEPLOY_RESULT=$?
if [ $DEPLOY_RESULT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ 部署成功!${NC}"
    echo -e "${GREEN}请查看上方输出获取已部署合约地址${NC}"
else
    echo ""
    echo -e "${YELLOW}❌ 部署失败，请检查错误信息${NC}"
    echo -e "${YELLOW}可能的问题:${NC}"
    echo -e "${YELLOW}1. anvil配置问题${NC}"
    echo -e "${YELLOW}2. 合约编译错误${NC}"
    echo -e "${YELLOW}3. 代码逻辑问题${NC}"
fi

# 自动关闭anvil
if [ ! -z "$ANVIL_PID" ]; then
    echo ""
    echo -e "${YELLOW}自动关闭anvil (PID: $ANVIL_PID)${NC}"
    kill $ANVIL_PID
    echo -e "${GREEN}✅ anvil已停止${NC}"
fi 
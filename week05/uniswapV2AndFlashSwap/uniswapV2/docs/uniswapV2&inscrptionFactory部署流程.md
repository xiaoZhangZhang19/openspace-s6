前置条件：
启动本地anvil环境
获得UniswapV2Pair.sol的creationcode，修改UniswapV2Library.sol中pairFor函数的init code hash

1.DeployUniswapV2.s.sol 部署uniswapV2合约
forge script script/DeployUniswapV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv

2.TestUniswapSimple.sol 测试uniswapV2合约是否正常添加流动性
forge script script/TestUniswapSimple.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv

3.DeployMemeFactoryOnly.sol 部署铭文工厂
forge script script/DeployMemeFactoryOnly.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv

4.DeployMemeAndAddLiquidity.sol 铸造meme同时添加uniswapV2的流动性
forge script script/DeployMemeAndAddLiquidity.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv

5.TestBuyMeme.sol 测试在Unswap的价格优于设定的起始价格时，用户可调用该函数来购买Meme
forge script script/TestBuyMeme.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv
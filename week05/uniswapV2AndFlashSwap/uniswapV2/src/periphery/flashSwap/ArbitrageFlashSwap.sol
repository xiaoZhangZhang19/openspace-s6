// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../../interfaces/IUniswapV2Callee.sol";
import "../../interfaces/IUniswapV2Pair.sol";
import "../../interfaces/IUniswapV2Factory.sol";
import "../../interfaces/IERC20.sol";
import "../../libraries/UniswapV2Library.sol";

/**
 * @title Uniswap V2池间套利闪电贷合约
 * @dev 利用不同Uniswap池子间的价格差异进行套利
 */
contract ArbitrageFlashSwap is IUniswapV2Callee {
    // 两个Uniswap V2工厂合约地址
    address public immutable factoryA;
    address public immutable factoryB;
    
    // 事件：记录套利结果
    event Arbitrage(
        address indexed token,
        address indexed weth,
        uint256 amountBorrowed,
        uint256 amountToRepay,
        uint256 profit
    );
    
    // 构造函数 - 设置两个Uniswap V2工厂地址
    constructor(address _factoryA, address _factoryB) {
        require(_factoryA != address(0) && _factoryB != address(0), "Invalid factory address");
        factoryA = _factoryA;
        factoryB = _factoryB;
    }
    
    /**
     * @dev 执行套利的入口函数
     * @param _token 要套利的代币地址
     * @param _weth WETH地址
     * @param _amountToken 借出的代币数量
     */
    function executeArbitrage(
        address _token,
        address _weth,
        uint256 _amountToken
    ) external {
        // 确定在哪个池子借，哪个池子卖
        address pairA = UniswapV2Library.pairFor(factoryA, _token, _weth);
        address pairB = UniswapV2Library.pairFor(factoryB, _token, _weth);
        
        require(pairA != address(0) && pairB != address(0), "Pairs do not exist");
        
        // 获取两个池子中的价格
        (uint reserveA0, uint reserveA1,) = IUniswapV2Pair(pairA).getReserves();
        (uint reserveB0, uint reserveB1,) = IUniswapV2Pair(pairB).getReserves();
        
        // 确定代币在配对中的顺序
        bool isToken0A = IUniswapV2Pair(pairA).token0() == _token;
        bool isToken0B = IUniswapV2Pair(pairB).token0() == _token;
        
        // 计算两个池子中代币的价格
        // 价格表示为: 1个代币能换多少WETH
        uint256 priceInPoolA = isToken0A 
            ? (reserveA1 * 1e18) / reserveA0 
            : (reserveA0 * 1e18) / reserveA1;
            
        uint256 priceInPoolB = isToken0B 
            ? (reserveB1 * 1e18) / reserveB0 
            : (reserveB0 * 1e18) / reserveB1;
        
        // 确定哪个池子价格更高(卖)，哪个价格更低(买)
        address borrowPair;
        address swapPair;
        bool borrowFromA;
        
        if (priceInPoolB > priceInPoolA) {
            // 从池子A借代币，在池子B卖出，获得更多WETH
            borrowPair = pairA;
            swapPair = pairB;
            borrowFromA = true;
        } else {
            // 从池子B借代币，在池子A卖出，获得更多WETH
            borrowPair = pairB;
            swapPair = pairA;
            borrowFromA = false;
        }
        
        // 确定代币在借贷池中的顺序
        address token0 = IUniswapV2Pair(borrowPair).token0();
        address token1 = IUniswapV2Pair(borrowPair).token1();
        
        // 设置借出金额
        uint amount0Out = _token == token0 ? _amountToken : 0;
        uint amount1Out = _token == token1 ? _amountToken : 0;
        
        // 准备传递给回调的数据
        bytes memory data = abi.encode(
            _token,
            _weth,
            borrowFromA,
            swapPair
        );
        
        // 执行闪电贷
        // 借出的token发送给当前合约，然后调用uniswapV2Call函数
        IUniswapV2Pair(borrowPair).swap(
            amount0Out,
            amount1Out,
            address(this),
            data
        );
    }
    
    /**
     * @dev UniswapV2回调函数，在闪电贷执行后被调用
     * @param _sender 调用者地址(pair合约)
     * @param _amount0 借出的token0数量
     * @param _amount1 借出的token1数量
     * @param _data 附加数据
     */
    function uniswapV2Call(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external override {
        // 验证最初的调用者是当前合约
        require(_sender == address(this), "Invalid flash loan sender");
        
        // 解码数据
        (
            address token,
            address weth,
            bool borrowFromA,
            // token价格较高的池子
            address swapPair
        ) = abi.decode(_data, (address, address, bool, address));
        
        // 安全检查：确保调用者是正确的Uniswap V2交易对
        address factory = borrowFromA ? factoryA : factoryB;
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = UniswapV2Library.pairFor(factory, token0, token1);
        
        require(msg.sender == pair, "Unauthorized callback");
        
        // 获取借到的代币数量
        uint256 amountBorrowed = _amount0 > 0 ? _amount0 : _amount1;
        
        // 计算需要偿还的金额(带有0.3%的手续费)
        uint256 fee = ((amountBorrowed * 3) + 996) / 997;
        uint256 amountToRepay = amountBorrowed + fee;
        
        // 在另一个池子中卖出所有借来的代币以获取WETH
        uint256 wethReceived = swapTokenForWETH(token, weth, amountBorrowed, swapPair);
        
        // 计算需要多少WETH来购买amountToRepay数量的token
        uint256 wethNeeded = calculateWETHNeededForToken(
            token,
            weth,
            amountToRepay,
            msg.sender
        );
        
        // 确保我们有足够的WETH来购买所需的token
        require(wethReceived > wethNeeded, "No arbitrage opportunity");
        
        // 用一部分WETH购买足够的token用于还款
        uint256 tokenReceived = swapWETHForToken(weth, token, wethNeeded, msg.sender);
        
        // 确保获得了足够的token来还款
        require(tokenReceived >= amountToRepay, "Insufficient token received for repay");
        
        // 将借来的代币连同费用一起归还给交易对
        IERC20(token).transfer(msg.sender, amountToRepay);
        
        // 计算并发送利润给交易发起者
        uint256 profit = wethReceived - wethNeeded;
        IERC20(weth).transfer(tx.origin, profit);
        
        // 发出套利事件
        emit Arbitrage(token, weth, amountBorrowed, amountToRepay, profit);
    }
    
    /**
     * @dev 计算购买指定数量token所需的WETH数量
     * @param token 代币地址
     * @param weth WETH地址
     * @param tokenAmount 需要购买的token数量
     * @param pair 交易对地址
     * @return 所需的WETH数量
     */
    function calculateWETHNeededForToken(
        address token,
        address weth,
        uint256 tokenAmount,
        address pair
    ) internal view returns (uint256) {
        // 确定交易对中代币的顺序
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        
        // 获取交易对的储备金
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        
        // 确定哪个储备是token，哪个是WETH
        uint reserveToken = token == token0 ? reserve0 : reserve1;
        uint reserveWETH = token == token0 ? reserve1 : reserve0;
        
        // 使用Uniswap公式计算所需的WETH数量
        // amountIn = (amountOut * reserveIn * 1000) / ((reserveOut - amountOut) * 997)
        uint256 numerator = tokenAmount * reserveWETH * 1000;
        uint256 denominator = (reserveToken - tokenAmount) * 997;
        
        // 添加1以处理舍入误差
        return (numerator / denominator) + 1;
    }
    
    /**
     * @dev 在指定交易对中用WETH交换token
     * @param weth WETH地址
     * @param token 代币地址
     * @param amountWETH WETH数量
     * @param pair 交易对地址
     * @return 获得的token数量
     */
    function swapWETHForToken(
        address weth,
        address token,
        uint256 amountWETH,
        address pair
    ) internal returns (uint256) {
        // 记录交换前的token余额
        uint256 tokenBalanceBefore = IERC20(token).balanceOf(address(this));
        
        // 将WETH发送到交易对
        IERC20(weth).transfer(pair, amountWETH);
        
        // 确定交易对中代币的顺序和计算输出量
        address token0 = IUniswapV2Pair(pair).token0();
        
        // 获取储备金并计算输出量
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        uint reserveIn = weth == token0 ? reserve0 : reserve1;
        uint reserveOut = weth == token0 ? reserve1 : reserve0;
        
        // 计算输出金额(使用Uniswap公式)
        uint amountInWithFee = amountWETH * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        uint amountOut = numerator / denominator;
        
        // 确定输出金额
        uint amount0Out = weth == token0 ? 0 : amountOut;
        uint amount1Out = weth == token0 ? amountOut : 0;
        
        // 执行交换
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), new bytes(0));
        
        // 记录交换后的token余额
        uint256 tokenBalanceAfter = IERC20(token).balanceOf(address(this));
        
        // 返回获得的token数量
        return tokenBalanceAfter - tokenBalanceBefore;
    }
    
    /**
     * @dev 在指定交易对中用代币交换WETH
     * @param token 代币地址
     * @param weth WETH地址
     * @param amountToken 代币数量
     * @param pair 交易对地址
     * @return 获得的WETH数量
     */
    function swapTokenForWETH(
        address token,
        address weth,
        uint256 amountToken,
        address pair
    ) internal returns (uint256) {
        // 记录交换前的WETH余额
        uint256 wethBalanceBefore = IERC20(weth).balanceOf(address(this));
        
        // 将代币发送到交易对
        IERC20(token).transfer(pair, amountToken);
        
        // 确定交易对中代币的顺序
        address token0 = IUniswapV2Pair(pair).token0();
        
        // 计算应该获得的WETH数量
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pair).getReserves();
        uint reserveIn = token == token0 ? reserve0 : reserve1;
        uint reserveOut = token == token0 ? reserve1 : reserve0;
        
        // 计算输出金额(使用Uniswap公式)
        uint amountInWithFee = amountToken * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        uint amountOut = numerator / denominator;
        
        // 确定输出金额
        uint amount0Out = token == token0 ? 0 : amountOut;
        uint amount1Out = token == token0 ? amountOut : 0;
        
        // 执行交换
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), new bytes(0));
        
        // 记录交换后的WETH余额
        uint256 wethBalanceAfter = IERC20(weth).balanceOf(address(this));
        
        // 返回获得的WETH数量
        return wethBalanceAfter - wethBalanceBefore;
    }
    
    /**
     * @dev 检查是否存在套利机会 (外部查询工具函数)
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址(通常是WETH)
     * @return 是否存在套利机会
     * @return 最优套利金额
     * @return 预期利润
     * 
     * 注意：此函数主要用于外部查询，如前端展示、机器人策略等
     * 不在 executeArbitrage 中调用以避免额外gas消耗
     * 
     * 使用场景：
     * 1. 前端界面展示套利机会
     * 2. 交易机器人筛选有利可图的交易
     * 3. 分析工具计算预期收益
     */
    function checkArbitrageOpportunity(
        address tokenA,
        address tokenB
    ) external view returns (bool, uint256, uint256) {
        // 使用工厂合约的getPair函数获取配对地址
        address pairA = IUniswapV2Factory(factoryA).getPair(tokenA, tokenB);
        address pairB = IUniswapV2Factory(factoryB).getPair(tokenA, tokenB);
        
        if (pairA == address(0) || pairB == address(0)) {
            return (false, 0, 0);
        }
        
        // 获取两个池子中的价格
        (uint reserveA0, uint reserveA1,) = IUniswapV2Pair(pairA).getReserves();
        (uint reserveB0, uint reserveB1,) = IUniswapV2Pair(pairB).getReserves();
        
        // 确定代币在配对中的顺序
        bool isToken0A = IUniswapV2Pair(pairA).token0() == tokenA;
        bool isToken0B = IUniswapV2Pair(pairB).token0() == tokenA;
        
        // 计算两个池子中代币的价格
        uint256 priceInPoolA = isToken0A 
            ? (reserveA1 * 1e18) / reserveA0 
            : (reserveA0 * 1e18) / reserveA1;
            
        uint256 priceInPoolB = isToken0B 
            ? (reserveB1 * 1e18) / reserveB0 
            : (reserveB0 * 1e18) / reserveB1;
        
        // 如果价格差异小于0.3%，则没有套利机会
        if (priceInPoolA > priceInPoolB) {
            if ((priceInPoolA * 997) / 1000 <= priceInPoolB) {
                return (false, 0, 0);
            }
        } else {
            if ((priceInPoolB * 997) / 1000 <= priceInPoolA) {
                return (false, 0, 0);
            }
        }
        
        // 简单起见，我们使用一个固定的套利金额
        uint256 arbitrageAmount = 1 ether;
        
        // 预估利润(简化计算)
        uint256 profit;
        if (priceInPoolA > priceInPoolB) {
            profit = ((arbitrageAmount * (priceInPoolA - priceInPoolB)) / 1e18) * 997 / 1000;
        } else {
            profit = ((arbitrageAmount * (priceInPoolB - priceInPoolA)) / 1e18) * 997 / 1000;
        }
        
        return (true, arbitrageAmount, profit);
    }
    
    // 允许合约接收ETH
    receive() external payable {}
} 
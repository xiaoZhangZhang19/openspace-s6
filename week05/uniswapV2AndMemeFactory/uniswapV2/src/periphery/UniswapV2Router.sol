// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import '../interfaces/IUniswapV2Factory.sol';
import '../libraries/TransferHelper.sol';
import '../interfaces/IUniswapV2Router02.sol';
import '../libraries/UniswapV2Library.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IUniswapV2Pair.sol';

/**
 * @title UniswapV2Router
 * @dev Uniswap V2路由器合约，处理添加/移除流动性和交换代币的逻辑
 * 这是一个简化版本，只包含核心功能
 */
contract UniswapV2Router is IUniswapV2Router02 {
    using SafeMath for uint;

    // 不可变的工厂合约地址
    address public immutable override factory;
    // 不可变的WETH合约地址
    address public immutable override WETH;

    /**
     * @dev 确保操作在截止时间前执行
     */
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }

    /**
     * @dev 构造函数
     * @param _factory 工厂合约地址
     * @param _WETH WETH合约地址
     */
    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @dev 接收ETH的函数
     * 只有WETH合约可以发送ETH到此合约
     */
    receive() external payable {
        assert(msg.sender == WETH); // 只接受来自WETH合约的ETH
    }

    // **** 添加流动性 ****
    /**
     * @dev 内部添加流动性函数
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param amountADesired 期望添加的代币A数量
     * @param amountBDesired 期望添加的代币B数量
     * @param amountAMin 最小接受的代币A数量
     * @param amountBMin 最小接受的代币B数量
     * @return amountA 实际添加的代币A数量
     * @return amountB 实际添加的代币B数量
     */
     //主要的作用是以A或者B为基准，计算出另一个代币的数量
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // 如果交易对不存在，创建它
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }
        
        // 获取交易对的储备量
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(factory, tokenA, tokenB);
        
        // 如果储备量为零（首次添加流动性），使用期望数量
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // 计算适当的B数量，给定A数量和储备比例
            uint amountBOptimal = UniswapV2Library.quote(amountADesired, reserveA, reserveB);
            
            // 如果计算的B数量小于等于期望的B数量
            if (amountBOptimal <= amountBDesired) {
                // 确保计算的B数量大于等于最小接受的B数量
                require(amountBOptimal >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // 否则，计算适当的A数量，给定B数量和储备比例
                uint amountAOptimal = UniswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                
                // 确保计算的A数量大于等于最小接受的A数量
                require(amountAOptimal >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    
    /**
     * @dev 添加流动性
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param amountADesired 期望添加的代币A数量
     * @param amountBDesired 期望添加的代币B数量
     * @param amountAMin 最小接受的代币A数量
     * @param amountBMin 最小接受的代币B数量
     * @param to 接收流动性代币的地址
     * @param deadline 操作截止时间
     * @return amountA 实际添加的代币A数量
     * @return amountB 实际添加的代币B数量
     * @return liquidity 铸造的流动性代币数量
     */
     //主要的作用是添加流动性，将代币A和代币B转移到交易对合约，并铸造流动性代币给到用户
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        // 计算最佳添加数量
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        
        // 将代币转移到交易对合约
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        
        // 铸造流动性代币
        liquidity = IUniswapV2Pair(pair).mint(to);
    }
    
    /**
     * @dev 添加ETH和代币的流动性
     * @param token 代币地址
     * @param amountTokenDesired 期望添加的代币数量
     * @param amountTokenMin 最小接受的代币数量
     * @param amountETHMin 最小接受的ETH数量
     * @param to 接收流动性代币的地址
     * @param deadline 操作截止时间
     * @return amountToken 实际添加的代币数量
     * @return amountETH 实际添加的ETH数量
     * @return liquidity 铸造的流动性代币数量
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        // 计算最佳添加数量
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        
        // 将代币转移到交易对合约
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        
        // 将ETH转换为WETH并转移到交易对合约Pair中
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        
        // 铸造流动性代币
        liquidity = IUniswapV2Pair(pair).mint(to);
        
        // 如果有剩余ETH，退还给发送者
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** 移除流动性 ****
    /**
     * @dev 移除流动性
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @param liquidity 要燃烧的流动性代币数量
     * @param amountAMin 最小接受的代币A数量
     * @param amountBMin 最小接受的代币B数量
     * @param to 接收代币的地址
     * @param deadline 操作截止时间
     * @return amountA 返还的代币A数量
     * @return amountB 返还的代币B数量
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        
        // 将流动性代币从用户转移到交易对合约
        IUniswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity);
        
        // 燃烧流动性代币，获取代币
        (uint amount0, uint amount1) = IUniswapV2Pair(pair).burn(to);
        
        // 以下代码都是做检查工作，如果不满足则会进行交易回滚
        // 排序代币地址，确定哪个是token0
        (address token0,) = UniswapV2Library.sortTokens(tokenA, tokenB);
        
        // 根据token0是否为tokenA，分配返回值
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        
        // 确保返还的代币数量大于等于最小接受数量
        require(amountA >= amountAMin, 'UniswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'UniswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    
    /**
     * @dev 移除ETH和代币的流动性
     * @param token 代币地址
     * @param liquidity 要燃烧的流动性代币数量
     * @param amountTokenMin 最小接受的代币数量
     * @param amountETHMin 最小接受的ETH数量
     * @param to 接收代币的地址
     * @param deadline 操作截止时间
     * @return amountToken 返还的代币数量
     * @return amountETH 返还的ETH数量
     */
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        // 移除流动性，但将代币发送到此合约
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            // 因此路由器合约需要作为中间人，先接收 WETH，然后将其转换为 ETH 并发送给用户。当然token也如此
            address(this),
            deadline
        );
        
        // 将代币转移给接收者
        TransferHelper.safeTransfer(token, to, amountToken);
        
        // 将WETH转换回ETH并发送给接收者
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    
    /**
     * @dev 使用permit签名移除流动性
     */
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        
        // 使用permit批准Router花费流动性代币
        // approveMax为true时，表示允许Router花费流动性代币的最大数量,否则就是指定的流动性代币数量
        uint value = approveMax ? type(uint).max : liquidity;
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        
        // 移除流动性
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    // **** 交换 ****
    /**
     * @dev 在一系列交易对中进行交换
     * @param amounts 每一步的数量数组
     * @param path 交易路径（代币地址数组）
     * @param _to 接收最终代币的地址
     */
    //主要的作用是执行交换，将输入代币转移到第一个交易对，并执行交换
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            
            // 如果不是最后一步，发送到下一个交易对；否则，发送到接收者
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            
            // 执行交换
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    
    /**
     * @dev 以确切的输入量交换代币
     * @param amountIn 输入的代币数量
     * @param amountOutMin 最小接受的输出代币数量
     * @param path 交易路径（代币地址数组），这个路径是uniswap来计算的，不需要我们手动计算
     * @param to 接收最终代币的地址，uniswap前端默认是当前链接的钱包地址
     * @param deadline 操作截止时间
     * @return amounts 路径上每一步的数量数组
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // 计算交易路径上的数量
        // 包含输入token数量以及应该输出的token数量
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        
        // 确保输出数量大于等于最小接受数量
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        
        // 执行交换
        _swap(amounts, path, to);
    }
    
    /**
     * @dev 以确切的ETH输入量交换代币
     * @param amountOutMin 最小接受的输出代币数量
     * @param path 交易路径（代币地址数组）
     * @param to 接收最终代币的地址
     * @param deadline 操作截止时间
     * @return amounts 路径上每一步的数量数组
     */
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // 确保路径的第一个代币是WETH
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 计算交易路径上的数量
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        
        // 确保输出数量大于等于最小接受数量
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 将ETH转换为WETH
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        
        // 执行交换
        _swap(amounts, path, to);
    }
    
    /**
     * @dev 以确切的代币输入量交换ETH
     * @param amountIn 输入的代币数量
     * @param amountOutMin 最小接受的ETH数量
     * @param path 交易路径（代币地址数组）
     * @param to 接收ETH的地址
     * @param deadline 操作截止时间
     * @return amounts 路径上每一步的数量数组
     */
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        // 确保路径的最后一个代币是WETH
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 计算交易路径上的数量
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
        
        // 确保输出数量大于等于最小接受数量
        require(amounts[amounts.length - 1] >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        
        // 执行交换，但将最终代币发送到此合约
        _swap(amounts, path, address(this));
        
        // 将WETH转换回ETH并发送给接收者
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    // **** 库函数 ****
    /**
     * @dev 根据储备量计算等价的代币数量
     */
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    /**
     * @dev 计算指定输入数量后的输出数量，考虑了交易手续费
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @dev 计算达到指定输出数量所需的输入数量，考虑了交易手续费
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /**
     * @dev 计算通过一系列交易对进行交易的输出数量
     */
    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    /**
     * @dev 计算达到指定输出数量所需的输入数量，通过一系列交易对
     */
    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
    
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        // 计算达到指定输出所需的输入数量
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        
        // 确保输入数量不超过最大值
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        
        // 执行交换
        _swap(amounts, path, to);
    }
    
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts) {
        // 确保路径的最后一个代币是WETH
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 计算达到指定输出所需的输入数量
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        
        // 确保输入数量不超过最大值
        require(amounts[0] <= amountInMax, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        
        // 执行交换，但将最终代币发送到此合约
        _swap(amounts, path, address(this));
        
        // 将WETH转换回ETH并发送给接收者
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts) {
        // 确保路径的第一个代币是WETH
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 计算达到指定输出所需的输入数量
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
        
        // 确保发送的ETH数量足够
        require(amounts[0] <= msg.value, 'UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        
        // 将ETH转换为WETH
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        
        // 执行交换
        _swap(amounts, path, to);
        
        // 如果有剩余ETH，退还给发送者
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    /**
     * @dev 支持转账费用代币的内部交换函数
     * @param path 交易路径（代币地址数组）
     * @param _to 接收最终代币的地址
     */
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
            
            uint amountInput;
            uint amountOutput;
            { // 避免堆栈太深错误
                // 获取储备量
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                
                // 计算实际输入数量（支持转账费用）
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                
                // 计算输出数量
                amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            
            // 确定输出参数
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            
            // 确定接收地址
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            
            // 执行交换
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        
        // 记录交换前的余额
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        
        // 执行支持转账费用的交换
        _swapSupportingFeeOnTransferTokens(path, to);
        
        // 确保输出数量满足最小要求
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) {
        // 确保路径的第一个代币是WETH
        require(path[0] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 记录输入数量
        uint amountIn = msg.value;
        
        // 将ETH转换为WETH
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
        
        // 记录交换前的余额
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        
        // 执行支持转账费用的交换
        _swapSupportingFeeOnTransferTokens(path, to);
        
        // 确保输出数量满足最小要求
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
            'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        // 确保路径的最后一个代币是WETH
        require(path[path.length - 1] == WETH, 'UniswapV2Router: INVALID_PATH');
        
        // 将输入代币转移到第一个交易对
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amountIn
        );
        
        // 执行支持转账费用的交换，但将最终代币发送到此合约
        _swapSupportingFeeOnTransferTokens(path, address(this));
        
        // 获取实际收到的WETH数量
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        
        // 确保输出数量满足最小要求
        require(amountOut >= amountOutMin, 'UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        
        // 将WETH转换回ETH并发送给接收者
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }
    
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        
        // 计算允许的数量
        uint value = approveMax ? type(uint).max : liquidity;
        
        // 使用permit批准Router花费流动性代币
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        
        // 移除流动性
        (amountToken, amountETH) = removeLiquidityETH(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }
    
    // **** 支持转账费用代币的移除ETH流动性 ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        // 移除流动性，但将代币发送到此合约
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        
        // 获取此合约的代币余额（支持转账费用）
        uint amountToken = IERC20(token).balanceOf(address(this));
        
        // 将代币转移给接收者（可能有转账费用）
        TransferHelper.safeTransfer(token, to, amountToken);
        
        // 将WETH转换回ETH并发送给接收者
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        // 获取交易对地址
        address pair = UniswapV2Library.pairFor(factory, token, WETH);
        
        // 计算允许的数量
        uint value = approveMax ? type(uint).max : liquidity;
        
        // 使用permit批准Router花费流动性代币
        IUniswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        
        // 移除支持转账费用的流动性
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }
}
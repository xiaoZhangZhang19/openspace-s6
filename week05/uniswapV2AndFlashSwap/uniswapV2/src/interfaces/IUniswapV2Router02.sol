// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title IUniswapV2Router02
 * @dev Uniswap V2路由器合约的接口
 * 继承了IUniswapV2Router01，并添加了对支持转账费用代币的支持
 */
interface IUniswapV2Router02 {
    /**
     * @dev 返回工厂合约地址
     */
    function factory() external view returns (address);
    
    /**
     * @dev 返回WETH合约地址
     */
    function WETH() external view returns (address);

    /**
     * @dev 添加流动性
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    /**
     * @dev 添加ETH和代币的流动性
     */
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    /**
     * @dev 移除流动性
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    
    /**
     * @dev 移除ETH和代币的流动性
     */
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    
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
    ) external returns (uint amountA, uint amountB);
    
    /**
     * @dev 使用permit签名移除ETH和代币的流动性
     */
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    
    /**
     * @dev 移除支持转账费用代币和ETH的流动性
     */
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    
    /**
     * @dev 使用permit签名移除支持转账费用代币和ETH的流动性
     */
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    /**
     * @dev 以确切的输入量交换代币
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    /**
     * @dev 交换代币以获得确切的输出量
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    /**
     * @dev 以确切的ETH输入量交换代币
     */
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    
    /**
     * @dev 交换代币以获得确切的ETH输出量
     */
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    
    /**
     * @dev 以确切的代币输入量交换ETH
     */
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    
    /**
     * @dev 交换ETH以获得确切的代币输出量
     */
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    /**
     * @dev 以确切的输入量交换支持转账费用的代币
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    
    /**
     * @dev 以确切的ETH输入量交换支持转账费用的代币
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    
    /**
     * @dev 以确切的代币输入量交换ETH，支持转账费用
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    /**
     * @dev 根据储备量计算等价的代币数量
     */
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    
    /**
     * @dev 计算指定输入数量后的输出数量，考虑了交易手续费
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    
    /**
     * @dev 计算达到指定输出数量所需的输入数量，考虑了交易手续费
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    
    /**
     * @dev 计算通过一系列交易对进行交易的输出数量
     */
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    
    /**
     * @dev 计算达到指定输出数量所需的输入数量，通过一系列交易对
     */
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
} 
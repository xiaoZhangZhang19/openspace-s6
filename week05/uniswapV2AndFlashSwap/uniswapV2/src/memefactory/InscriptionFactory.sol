// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./InscriptionToken.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";

/**
 * @title 铭文工厂合约
 * @dev 用于部署和管理铭文代币合约的工厂合约
 * @notice 该合约使用最小代理模式来部署新的铭文代币
 */
contract InscriptionFactory is Ownable {
    using Clones for address;

    /// @notice 铭文代币实现合约地址
    address public immutable tokenImplementation;
    /// @notice 铸造费用百分比（10%）
    uint256 public constant FEE_PERCENTAGE = 10;
    /// @notice 工厂费用百分比（5%）- 用于添加流动性
    uint256 public constant FACTORY_FEE_PERCENTAGE = 5;
    /// @notice 记录地址是否为工厂创建的铭文代币
    mapping(address => bool) public isInscriptionToken;
    /// @notice 代币符号到代币地址的映射
    mapping(string => address) public inscriptions;
    /// @notice 部署铭文代币的费用
    uint256 public fee;
    /// @notice Uniswap V2 路由器地址
    address public uniswapRouter;
    /// @notice WETH 地址
    address public weth;
    /// @notice 记录代币是否已经添加过流动性
    mapping(address => bool) public liquidityAdded;
    
    /**
     * @notice 铭文代币部署事件
     * @param symbol 代币符号
     * @param token 部署的代币合约地址
     */
    event InscriptionDeployed(string indexed symbol, address indexed token);

    /**
     * @notice 铭文代币铸造事件
     * @param symbol 代币符号
     * @param to 铸造者地址
     * @param amount 铸造数量
     */
    event InscriptionMinted(string indexed symbol, address indexed to, uint256 amount);

    /**
     * @notice 流动性添加事件
     * @param token 代币地址
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     * @param liquidity LP代币数量
     */
    event LiquidityAdded(address indexed token, uint256 tokenAmount, uint256 ethAmount, uint256 liquidity);

    /**
     * @dev 构造函数，部署实现合约并设置所有者
     */
    constructor() Ownable(msg.sender) {
        tokenImplementation = address(new InscriptionToken());
    }

    /**
     * @notice 设置铸造费用
     * @param _fee 新的铸造费用
     */
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice 设置Uniswap路由器地址
     * @param _router Uniswap V2路由器地址
     */
    function setUniswapRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        uniswapRouter = _router;
        weth = IUniswapV2Router02(uniswapRouter).WETH();
    }
    
    /**
     * @notice 设置Uniswap路由器地址（不调用WETH函数）
     * @param _router Uniswap V2路由器地址
     */
    function setUniswapRouterDirect(address _router) external onlyOwner {
        require(_router != address(0), "Invalid router address");
        uniswapRouter = _router;
    }
    
    /**
     * @notice 手动设置WETH地址
     * @param _weth WETH地址
     */
    function setWeth(address _weth) external onlyOwner {
        require(_weth != address(0), "Invalid WETH address");
        weth = _weth;
    }

    /**
     * @notice 部署新的铭文代币合约
     * @param symbol 代币符号
     * @param totalSupply 代币总供应量
     * @param perMint 每次铸造数量
     * @param price 铸造价格（单位：wei）
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external payable {
        require(msg.value >= fee, "Insufficient fee");
        require(inscriptions[symbol] == address(0), "Symbol already exists");
        require(totalSupply > 0, "Total supply must be positive");
        // 铸造数量不能大于总供应量
        require(perMint > 0 && perMint <= totalSupply, "Invalid perMint amount");
        require(price > 0, "Price must be positive");

        // 使用代理模式克隆实现合约，只部署一个最小代理合约（约 45 字节）
        // 所有调用都delegatecall委托给实现合约，大大节省 gas 成本
        address payable clone = payable(tokenImplementation.clone());
        // 初始化代理合约
        InscriptionToken(clone).initialize(symbol, totalSupply, perMint, price, msg.sender);
        
        isInscriptionToken[clone] = true;
        inscriptions[symbol] = clone;
        emit InscriptionDeployed(symbol, clone);

        // 如果有多余的 ETH，返还给发送者
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
    }

    /**
     * @notice 铸造铭文代币
     * @param symbol 代币符号
     */
    function mintInscription(string memory symbol) external payable {
        require(inscriptions[symbol] != address(0), "Token not created by this factory");
        
        address payable tokenAddr = payable(inscriptions[symbol]);
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 mintPrice = token.mintPrice();

        // 计算给合约拥有者的10%费用
        uint256 platformFee = (mintPrice * FEE_PERCENTAGE) / 100;
        // 计算工厂收取的5%费用 - 用于添加流动性
        uint256 factoryFee = (mintPrice * FACTORY_FEE_PERCENTAGE) / 100;
        // 用户只需要支付：代币费用 + 平台费用 + 工厂费用
        uint256 totalRequired = mintPrice + platformFee + factoryFee;
        require(msg.value >= totalRequired, "Insufficient payment");

        // 铸造代币给用户
        token.mintTo{value: mintPrice}(msg.sender);

        // 工厂费用留在合约中，等待手动添加流动性

        // 如果有多余的 ETH，返还给发送者
        uint256 excess = msg.value - totalRequired;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }

        emit InscriptionMinted(symbol, msg.sender, token.perMintAmount());
    }

    /**
     * @notice 为代币购买并添加流动性（一键操作）
     * @param symbol 代币符号
     * @param totalEthAmount 总ETH数量
     */
    function buyAndAddLiquidity(string memory symbol, uint256 totalEthAmount) external onlyOwner {
        require(inscriptions[symbol] != address(0), "Token not created by this factory");
        require(uniswapRouter != address(0), "Uniswap router not set");
        // 确保合约余额至少是totalEthAmount的两倍，以应对所有可能的情况
        require(address(this).balance >= totalEthAmount * 2, "Insufficient ETH balance, need at least twice the amount");
        
        address payable tokenAddr = payable(inscriptions[symbol]);
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 检查是否是第一次添加流动性（通过检查Uniswap池子是否存在）
        address factory = IUniswapV2Router02(uniswapRouter).factory();
        address pair = IUniswapV2Factory(factory).getPair(tokenAddr, weth);
        bool isFirstLiquidity = (pair == address(0)) || (IERC20(pair).totalSupply() == 0);
        
        uint256 mintPrice = token.mintPrice();
        uint256 perMintAmount = token.perMintAmount();
        
        if (isFirstLiquidity) {
            // 第一次添加流动性：按mint价格设定初始比例
            // 简单策略：用一半ETH购买代币，一半ETH用于流动性
            uint256 ethForTokens = totalEthAmount / 2;
            uint256 ethForLiquidity = totalEthAmount - ethForTokens;
            
            require(ethForTokens > 0 && ethForLiquidity > 0, "Invalid ETH distribution");
            
            // 购买代币
            token.mintTo{value: ethForTokens}(address(this));
            uint256 actualTokenAmount = (ethForTokens * perMintAmount) / mintPrice;
            
            // 计算按mint价格应该用多少代币配对ethForLiquidity
            uint256 idealTokenAmount = (ethForLiquidity * perMintAmount) / mintPrice;
            
            // 使用实际购买的代币数量和理想数量中的较小值
            uint256 tokenAmountForLiquidity = actualTokenAmount < idealTokenAmount ? actualTokenAmount : idealTokenAmount;
            
            // 如果按理想比例，计算实际需要的ETH
            uint256 actualEthForLiquidity = (tokenAmountForLiquidity * mintPrice) / perMintAmount;
            
            // 添加流动性，保持mint价格比例
            _addLiquidity(tokenAddr, tokenAmountForLiquidity, actualEthForLiquidity);
        } else {
            // 已有流动性：按照现有比例添加
            // 获取当前池子的比例
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
            address token0 = IUniswapV2Pair(pair).token0();
            
            uint256 tokenReserve = token0 == tokenAddr ? reserve0 : reserve1;
            uint256 ethReserve = token0 == weth ? reserve0 : reserve1;
            
            require(tokenReserve > 0 && ethReserve > 0, "Invalid reserves");
            
            // 按照现有比例计算需要的代币数量
            uint256 tokenAmountNeeded = (totalEthAmount * tokenReserve) / ethReserve;
            
            // 检查合约是否有足够的代币，如果不够就购买
            uint256 currentTokenBalance = IERC20(tokenAddr).balanceOf(address(this));
            if (currentTokenBalance < tokenAmountNeeded) {
                uint256 tokenDeficit = tokenAmountNeeded - currentTokenBalance;
                uint256 ethNeededForTokens = (tokenDeficit * mintPrice) / perMintAmount;
                
                // 购买不足的代币
                token.mintTo{value: ethNeededForTokens}(address(this));
            }
            
            // 按照现有比例添加流动性
            _addLiquidity(tokenAddr, tokenAmountNeeded, totalEthAmount);
        }
    }



    /**
     * @notice 检查Uniswap价格是否比铸造价格更优
     * @param tokenAddr 代币地址
     * @param ethAmount ETH数量
     * @return 如果Uniswap价格更优则返回true
     */
    function _isPriceMoreFavorable(address tokenAddr, uint256 ethAmount) internal view returns (bool) {
        InscriptionToken token = InscriptionToken(payable(tokenAddr));
        
        // 获取Uniswap上的价格
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenAddr;
        
        uint256 mintPrice = token.mintPrice();
        uint256[] memory amountsOut = IUniswapV2Router02(uniswapRouter).getAmountsOut(ethAmount, path);
        
        // 计算价格比例
        uint256 uniswapTokenAmount = amountsOut[1];
        uint256 mintTokenAmount = token.perMintAmount();
        uint256 mintEthAmount = mintPrice + (mintPrice * FEE_PERCENTAGE) / 100 + (mintPrice * FACTORY_FEE_PERCENTAGE) / 100;
        uint256 uniswapRate = (uniswapTokenAmount * 1e18) / ethAmount;
        uint256 mintRate = (mintTokenAmount * 1e18) / mintEthAmount;
        
        return uniswapRate > mintRate;
    }

    /**
     * @notice 从Uniswap购买铭文代币
     * @param symbol 代币符号
     * @param amountOutMin 最小获得代币数量
     * @param deadline 交易截止时间
     */
    function buyMeme(
        string memory symbol,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable {
        require(inscriptions[symbol] != address(0), "Token not created by this factory");
        require(uniswapRouter != address(0), "Uniswap router not set");
        
        address payable tokenAddr = payable(inscriptions[symbol]);
        
        // 检查是否已添加流动性
        require(liquidityAdded[tokenAddr], "No liquidity available");
        
        // 检查价格是否更优
        require(_isPriceMoreFavorable(tokenAddr, msg.value), "Mint price is better than Uniswap price");
        
        // 创建交易路径
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenAddr;
        
        // 从Uniswap购买代币
        IUniswapV2Router02(uniswapRouter).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            deadline
        );
    }

    /**
     * @notice 内部函数，添加ETH和代币的流动性
     * @param tokenAddr 代币地址
     * @param tokenAmount 代币数量
     * @param ethAmount ETH数量
     */
    function _addLiquidity(address tokenAddr, uint256 tokenAmount, uint256 ethAmount) internal {
        require(uniswapRouter != address(0), "Uniswap router not set");
        
        // 授权路由器使用代币
        IERC20(tokenAddr).approve(uniswapRouter, tokenAmount);
        
        // 添加流动性
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = IUniswapV2Router02(uniswapRouter).addLiquidityETH{value: ethAmount}(
            tokenAddr,
            tokenAmount,
            0, // 最小代币数量
            0, // 最小ETH数量
            address(this), // LP代币接收者
            block.timestamp + 15 minutes // 截止时间
        );
        
        // 标记已添加流动性
        liquidityAdded[tokenAddr] = true;
        
        emit LiquidityAdded(tokenAddr, amountToken, amountETH, liquidity);
    }

    /**
     * @notice 工厂合约owner提取合约中的以太币
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice 提取合约中的LP代币
     * @param token 代币地址
     */
    function withdrawLPTokens(address token) external onlyOwner {
        address factory = IUniswapV2Router02(uniswapRouter).factory();
        address pair = IUniswapV2Factory(factory).getPair(token, weth);
        require(pair != address(0), "Pair does not exist");
        
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        require(lpBalance > 0, "No LP tokens to withdraw");
        
        IERC20(pair).transfer(owner(), lpBalance);
    }

    receive() external payable {}
} 
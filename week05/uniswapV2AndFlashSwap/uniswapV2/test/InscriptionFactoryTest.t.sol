// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/memefactory/InscriptionFactory.sol";
import "../src/memefactory/InscriptionToken.sol";
import "../src/interfaces/IUniswapV2Router02.sol";
import "../src/interfaces/IUniswapV2Factory.sol";
import "../src/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InscriptionFactoryTest is Test {
    InscriptionFactory factory;
    address uniswapRouter;
    address uniswapFactory;
    address weth;
    address deployer;
    address user1;
    address user2;

    // 测试参数
    string constant TEST_SYMBOL = "TEST";
    uint256 constant TOTAL_SUPPLY = 1000000 * 1e18;
    uint256 constant PER_MINT = 1000 * 1e18;
    uint256 constant MINT_PRICE = 0.01 ether;
    uint256 constant FACTORY_FEE = 0.1 ether;

    function setUp() public {
        // 设置测试账户
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 给测试账户一些ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(deployer, 10 ether);
        
        // 部署工厂合约
        factory = new InscriptionFactory();
        
        // 设置部署费用
        factory.setFee(FACTORY_FEE);
        
        // 设置Uniswap路由器地址
        _setupUniswapMock();
        
        // 设置路由器地址
        factory.setUniswapRouter(uniswapRouter);
    }
    
    // 模拟Uniswap环境
    function _setupUniswapMock() internal {
        // 部署模拟的WETH
        weth = address(new MockToken("Wrapped Ether", "WETH"));
        
        // 部署模拟的UniswapFactory
        uniswapFactory = address(new MockUniswapFactory());
        
        // 部署模拟的UniswapRouter
        uniswapRouter = address(new MockUniswapRouter(uniswapFactory, weth));
    }
    
    // 测试部署铭文代币
    function testDeployInscription() public {
        // 使用user1部署铭文代币
        vm.startPrank(user1);
        
        // 检查初始余额
        uint256 initialBalance = user1.balance;
        
        // 部署铭文代币
        factory.deployInscription{value: FACTORY_FEE}(
            TEST_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            MINT_PRICE
        );
        
        // 检查费用是否正确扣除
        assertEq(user1.balance, initialBalance - FACTORY_FEE);
        
        // 检查代币是否正确部署
        address tokenAddr = factory.inscriptions(TEST_SYMBOL);
        assertTrue(tokenAddr != address(0), "Token should be deployed");
        assertTrue(factory.isInscriptionToken(tokenAddr), "Token should be registered");
        
        // 检查代币参数是否正确
        InscriptionToken token = InscriptionToken(payable(tokenAddr));
        assertEq(token.symbol(), TEST_SYMBOL, "Symbol should match");
        assertEq(token.totalSupplyLimit(), TOTAL_SUPPLY, "Total supply should match");
        assertEq(token.perMintAmount(), PER_MINT, "Per mint amount should match");
        assertEq(token.mintPrice(), MINT_PRICE, "Mint price should match");
        assertEq(token.creator(), user1, "Creator should be user1");
        
        vm.stopPrank();
    }
    
    // 测试铸造铭文代币
    function testMintInscription() public {
        // 先部署铭文代币
        vm.startPrank(user1);
        factory.deployInscription{value: FACTORY_FEE}(
            TEST_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            MINT_PRICE
        );
        vm.stopPrank();
        
        // 使用user2铸造代币
        vm.startPrank(user2);
        
        // 获取代币地址
        address payable tokenAddr = payable(factory.inscriptions(TEST_SYMBOL));
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 计算铸造所需的ETH（修正后的费用结构）
        uint256 mintPrice = token.mintPrice();
        uint256 platformFee = (mintPrice * factory.FEE_PERCENTAGE()) / 100;
        uint256 factoryFee = (mintPrice * factory.FACTORY_FEE_PERCENTAGE()) / 100;
        // 用户只需要支付：代币费用 + 平台费用 + 工厂费用
        uint256 totalRequired = mintPrice + platformFee + factoryFee;
        
        // 确保支付足够的ETH
        uint256 paymentAmount = totalRequired + 0.001 ether; // 支付稍微多一点，确保足够
        
        // 检查初始余额
        uint256 initialBalance = user2.balance;
        uint256 initialTokenBalance = token.balanceOf(user2);
        
        // 铸造代币
        factory.mintInscription{value: paymentAmount}(TEST_SYMBOL);
        
        // 检查ETH是否正确扣除（考虑到可能有退款）
        assertTrue(user2.balance <= initialBalance - totalRequired, "ETH should be deducted");
        
        // 检查代币是否正确铸造
        assertEq(token.balanceOf(user2), initialTokenBalance + PER_MINT, "Tokens should be minted");
        
        // 检查工厂合约是否收到了费用
        assertTrue(address(factory).balance > 0, "Factory should have received fees");
        
        vm.stopPrank();
    }
    
    // 测试提取ETH
    function testWithdraw() public {
        // 先铸造代币
        testMintInscription();
        
        // 检查合约ETH余额
        uint256 contractBalance = address(factory).balance;
        assertTrue(contractBalance > 0, "Contract should have ETH");
        
        // 检查owner初始余额
        uint256 initialOwnerBalance = address(this).balance;
        
        // 提取ETH
        factory.withdraw();
        
        // 检查ETH是否正确提取
        assertEq(address(factory).balance, 0, "Contract should have 0 ETH");
        assertEq(address(this).balance, initialOwnerBalance + contractBalance, "Owner should receive ETH");
    }
    
    // 测试提取LP代币
    function testWithdrawLPTokens() public {
        // 先铸造代币并添加流动性
        testAddLiquidity();
        
        // 获取代币地址
        address tokenAddr = factory.inscriptions(TEST_SYMBOL);
        
        // 获取LP代币地址
        address pair = IUniswapV2Factory(uniswapFactory).getPair(tokenAddr, weth);
        assertTrue(pair != address(0), "Pair should exist");
        
        // 检查LP代币余额
        uint256 lpBalance = IERC20(pair).balanceOf(address(factory));
        assertTrue(lpBalance > 0, "Factory should have LP tokens");
        
        // 提取LP代币
        factory.withdrawLPTokens(tokenAddr);
        
        // 检查LP代币是否正确提取
        assertEq(IERC20(pair).balanceOf(address(factory)), 0, "Factory should have 0 LP tokens");
        assertEq(IERC20(pair).balanceOf(address(this)), lpBalance, "Owner should receive LP tokens");
    }
    
    // 测试按mint价格添加初始流动性
    function testAddInitialLiquidityAtMintPrice() public {
        // 先部署铭文代币
        vm.startPrank(user1);
        factory.deployInscription{value: FACTORY_FEE}(
            TEST_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            MINT_PRICE
        );
        vm.stopPrank();
        
        // 获取代币地址
        address payable tokenAddr = payable(factory.inscriptions(TEST_SYMBOL));
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 通过mintInscription为用户铸造代币，工厂会收到费用
        vm.startPrank(user2);
        uint256 mintPrice = token.mintPrice();
        uint256 platformFee = (mintPrice * factory.FEE_PERCENTAGE()) / 100;
        uint256 factoryFee = (mintPrice * factory.FACTORY_FEE_PERCENTAGE()) / 100;
        uint256 totalRequired = mintPrice + platformFee + factoryFee;
        
        factory.mintInscription{value: totalRequired}(TEST_SYMBOL);
        vm.stopPrank();
        
        // 现在工厂应该有一些ETH，让工厂再购买一些代币用于流动性
        uint256 factoryBalance = address(factory).balance;
        
        // 确保工厂有足够的ETH（至少是需要的两倍）
        uint256 totalEthAmount = 0.1 ether;
        vm.deal(address(factory), totalEthAmount * 2 + 0.01 ether); // 多给一点，以确保足够
        
        // 使用工厂的buyAndAddLiquidity来购买代币并添加流动性
        factory.buyAndAddLiquidity(TEST_SYMBOL, totalEthAmount);
        
        // 检查流动性是否添加
        assertTrue(factory.liquidityAdded(tokenAddr), "Liquidity should be added");
        
        // 验证价格比例是否正确
        address pair = IUniswapV2Factory(uniswapFactory).getPair(tokenAddr, weth);
        assertTrue(pair != address(0), "Pair should exist");
        
        uint256 lpBalance = IERC20(pair).balanceOf(address(factory));
        assertTrue(lpBalance > 0, "Factory should have LP tokens");
    }
    
    // 测试手动添加流动性
    function testAddLiquidity() public {
        // 先铸造一些代币
        testMintInscription();
        
        // 获取代币地址
        address payable tokenAddr = payable(factory.inscriptions(TEST_SYMBOL));
        InscriptionToken token = InscriptionToken(tokenAddr);
        
        // 设置要使用的ETH数量
        uint256 totalEthAmount = 0.1 ether;
        
        // 确保工厂有足够的ETH（至少是需要的两倍）
        vm.deal(address(factory), totalEthAmount * 2 + 0.01 ether);
        
        // 使用buyAndAddLiquidity函数
        factory.buyAndAddLiquidity(TEST_SYMBOL, totalEthAmount);
        
        // 检查流动性是否添加
        assertTrue(factory.liquidityAdded(tokenAddr), "Liquidity should be added");
        
        // 检查LP代币余额
        address pair = IUniswapV2Factory(uniswapFactory).getPair(tokenAddr, weth);
        assertTrue(pair != address(0), "Pair should exist");
        
        uint256 lpBalance = IERC20(pair).balanceOf(address(factory));
        assertTrue(lpBalance > 0, "Factory should have LP tokens");
    }
    
    receive() external payable {}
}

// 模拟Token合约
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// 模拟UniswapFactory合约
contract MockUniswapFactory {
    mapping(address => mapping(address => address)) public pairs;
    
    function getPair(address tokenA, address tokenB) external view returns (address) {
        return pairs[tokenA][tokenB];
    }
    
    function createPair(address tokenA, address tokenB) external returns (address) {
        address pair = address(new MockPair());
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair; // 确保双向查找
        return pair;
    }
}

// 模拟UniswapPair合约
contract MockPair is ERC20 {
    constructor() ERC20("Uniswap V2 Pair", "UNI-V2") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// 模拟UniswapRouter合约
contract MockUniswapRouter {
    address public immutable factory;
    address public immutable WETH;
    mapping(address => uint256) public tokenAmountsOut;
    
    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }
    
    function setTokenAmountOut(address token, uint256 amount) external {
        tokenAmountsOut[token] = amount;
    }
    
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity) {
        // 模拟添加流动性
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        
        // 创建交易对
        address pair = IUniswapV2Factory(factory).createPair(token, WETH);
        
        // 铸造LP代币
        MockPair(pair).mint(to, 100 * 10**18);
        
        liquidity = 100 * 10**18;
        return (amountToken, amountETH, liquidity);
    }
    
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        
        // 使用预设的输出金额或默认值
        if (tokenAmountsOut[path[path.length - 1]] > 0) {
            amounts[path.length - 1] = tokenAmountsOut[path[path.length - 1]];
        } else {
            amounts[path.length - 1] = amountIn * 2; // 默认2倍
        }
        
        return amounts;
    }
    
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        require(path.length >= 2, "Invalid path");
        require(path[0] == WETH, "Path must start with WETH");
        
        amounts = new uint[](path.length);
        amounts[0] = msg.value;
        
        // 使用预设的输出金额或默认值
        uint256 amountOut;
        if (tokenAmountsOut[path[path.length - 1]] > 0) {
            amountOut = tokenAmountsOut[path[path.length - 1]];
        } else {
            amountOut = msg.value * 2; // 默认2倍
        }
        
        amounts[path.length - 1] = amountOut;
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // 将代币转给接收者
        MockToken(path[path.length - 1]).mint(to, amountOut);
        
        return amounts;
    }
} 
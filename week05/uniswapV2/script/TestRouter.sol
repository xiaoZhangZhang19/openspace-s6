// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Factory.sol";
import "../src/periphery/WETH.sol";
import "../src/periphery/UniswapV2Router.sol";
import "../src/periphery/ERC20.sol";

contract TestRouterScript is Script {
    UniswapV2Factory public factory;
    WETH public weth;
    UniswapV2Router public router;
    ERC20 public tokenA;
    ERC20 public tokenB;
    
    // 测试用户地址
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function run() public {
        // 设置测试账户
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        
        // 开始以alice身份执行操作
        vm.startPrank(alice);
        
        // 部署合约
        console.log("Deploying contracts...");
        factory = new UniswapV2Factory(alice);
        weth = new WETH();
        router = new UniswapV2Router(address(factory), address(weth));
        
        // 部署测试代币
        tokenA = new ERC20("Token A", "TKA", 18);
        tokenB = new ERC20("Token B", "TKB", 18);
        
        // 铸造测试代币
        tokenA.mint(alice, 1000000 ether);
        tokenB.mint(alice, 1000000 ether);
        
        // 测试添加流动性
        testAddLiquidity();
        
        // 测试代币兑换
        testSwapExactTokensForTokens();
        testSwapTokensForExactTokens();
        
        // 测试ETH相关功能
        testAddLiquidityETH();
        testSwapExactETHForTokens();
        testSwapExactTokensForETH();
        testSwapETHForExactTokens();
        testSwapTokensForExactETH();
        
        // 测试移除流动性
        testRemoveLiquidity();
        testRemoveLiquidityETH();
        
        console.log("All tests completed!");
    }
    
    /**
     * @dev 测试添加流动性功能
     * 向代币对A-B添加等值的代币，创建流动性池并获得流动性代币
     */
    function testAddLiquidity() internal {
        console.log("\nTesting addLiquidity...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 100 ether);
        tokenB.approve(address(router), 100 ether);
        
        // 添加流动性
        // 参数说明:
        // 1,2: 代币A和代币B的地址
        // 3,4: 期望添加的代币A和代币B数量
        // 5,6: 可接受的最小代币A和代币B数量（防止滑点）
        // 7: 接收流动性代币的地址
        // 8: 交易截止时间（超过此时间交易失败）
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            100 ether,
            100 ether,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        console.log("Add liquidity success:");
        console.log("- Added tokenA amount:", amountA / 1e18);
        console.log("- Added tokenB amount:", amountB / 1e18);
        console.log("- Received liquidity tokens:", liquidity / 1e18);
        
        // 验证结果
        address pair = factory.getPair(address(tokenA), address(tokenB));
        require(pair != address(0), "Failed to create pair");
        require(ERC20(pair).balanceOf(alice) > 0, "No liquidity tokens received");
    }
    
    /**
     * @dev 测试固定输入的代币兑换功能
     * 使用固定数量的代币A兑换尽可能多的代币B
     */
    function testSwapExactTokensForTokens() internal {
        console.log("\nTesting swapExactTokensForTokens...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 10 ether);
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // 记录兑换前的余额
        uint balanceBefore = tokenB.balanceOf(alice);
        
        // 兑换代币
        // 参数说明:
        // 1: 精确输入的代币A数量
        // 2: 期望获得的最小代币B数量（防止滑点）
        // 3: 交易路径数组
        // 4: 接收代币的地址
        // 5: 交易截止时间
        uint[] memory amounts = router.swapExactTokensForTokens(
            10 ether,
            0,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的余额
        uint balanceAfter = tokenB.balanceOf(alice);
        
        console.log("Swap success:");
        console.log("- Input tokenA amount:", amounts[0] / 1e18);
        console.log("- Received tokenB amount:", amounts[1] / 1e18);
        
        // 验证结果
        require(balanceAfter > balanceBefore, "Swap failed");
        require(amounts[1] == balanceAfter - balanceBefore, "Amounts don't match");
    }
    
    /**
     * @dev 测试固定输出的代币兑换功能
     * 使用尽可能少的代币A兑换固定数量的代币B
     */
    function testSwapTokensForExactTokens() internal {
        console.log("\nTesting swapTokensForExactTokens...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 20 ether);
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        
        // 记录兑换前的余额
        uint balanceBefore = tokenB.balanceOf(alice);
        
        // 兑换代币
        // 参数说明:
        // 1: 精确输出的代币B数量
        // 2: 愿意支付的最大代币A数量（防止滑点）
        // 3: 交易路径数组
        // 4: 接收代币的地址
        // 5: 交易截止时间
        uint[] memory amounts = router.swapTokensForExactTokens(
            5 ether,
            20 ether,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的余额
        uint balanceAfter = tokenB.balanceOf(alice);
        
        console.log("Swap success:");
        console.log("- Input tokenA amount:", amounts[0] / 1e18);
        console.log("- Received tokenB amount:", amounts[1] / 1e18);
        
        // 验证结果：确保获得的代币B数量与指定的精确输出数量一致
        require(balanceAfter - balanceBefore == 5 ether, "Didn't receive exact output amount");
    }
    
    /**
     * @dev 测试添加ETH流动性功能
     * 将ETH和代币A添加到流动性池
     */
    function testAddLiquidityETH() internal {
        console.log("\nTesting addLiquidityETH...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 50 ether);
        
        // 添加ETH流动性
        // 参数说明（类似addLiquidity，但使用ETH替代其中一种代币）:
        // 1: 代币地址
        // 2: 期望添加的代币数量
        // 3,4: 可接受的最小代币和ETH数量
        // 5: 接收流动性代币的地址
        // 6: 交易截止时间
        // 使用{value: x}发送ETH
        (uint amountToken, uint amountETH, uint liquidity) = router.addLiquidityETH{value: 10 ether}(
            address(tokenA),
            50 ether,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        console.log("Add ETH liquidity success:");
        console.log("- Added tokenA amount:", amountToken / 1e18);
        console.log("- Added ETH amount:", amountETH / 1e18);
        console.log("- Received liquidity tokens:", liquidity / 1e18);
        
        // 验证结果
        address pair = factory.getPair(address(tokenA), address(weth));
        require(pair != address(0), "Failed to create ETH pair");
        require(ERC20(pair).balanceOf(alice) > 0, "No ETH liquidity tokens received");
    }
    
    /**
     * @dev 测试固定输入的ETH兑换代币功能
     * 使用固定数量的ETH兑换尽可能多的代币A
     */
    function testSwapExactETHForTokens() internal {
        console.log("\nTesting swapExactETHForTokens...");
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        // 记录兑换前的余额
        uint balanceBefore = tokenA.balanceOf(alice);
        
        // 兑换ETH为代币
        // 参数与swapExactTokensForTokens类似，但使用{value: x}发送ETH
        uint[] memory amounts = router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的余额
        uint balanceAfter = tokenA.balanceOf(alice);
        
        console.log("Swap success:");
        console.log("- Input ETH amount:", amounts[0] / 1e18);
        console.log("- Received tokenA amount:", amounts[1] / 1e18);
        
        // 验证结果
        require(balanceAfter > balanceBefore, "ETH swap failed");
    }
    
    /**
     * @dev 测试固定输入的代币兑换ETH功能
     * 使用固定数量的代币A兑换尽可能多的ETH
     */
    function testSwapExactTokensForETH() internal {
        console.log("\nTesting swapExactTokensForETH...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 10 ether);
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        // 记录兑换前的ETH余额
        uint balanceBefore = alice.balance;
        
        // 兑换代币为ETH
        uint[] memory amounts = router.swapExactTokensForETH(
            10 ether,
            0,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的ETH余额
        uint balanceAfter = alice.balance;
        
        console.log("Swap success:");
        console.log("- Input tokenA amount:", amounts[0] / 1e18);
        console.log("- Received ETH amount:", amounts[1] / 1e18);
        
        // 验证结果
        require(balanceAfter > balanceBefore, "Token to ETH swap failed");
    }
    
    /**
     * @dev 测试固定输出的ETH兑换代币功能
     * 使用尽可能少的ETH兑换固定数量的代币A
     */
    function testSwapETHForExactTokens() internal {
        console.log("\nTesting swapETHForExactTokens...");
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);
        
        // 记录兑换前的余额
        uint balanceBefore = tokenA.balanceOf(alice);
        
        // 使用ETH兑换精确数量的代币
        // 参数说明:
        // 1: 精确输出的代币A数量
        // 2,3,4,5: 交易路径、接收地址、截止时间
        // {value: x}: 愿意支付的最大ETH数量（多余的会退还）
        uint[] memory amounts = router.swapETHForExactTokens{value: 5 ether}(
            2 ether,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的余额
        uint balanceAfter = tokenA.balanceOf(alice);
        
        console.log("Swap success:");
        console.log("- Input ETH amount:", amounts[0] / 1e18);
        console.log("- Received tokenA amount:", amounts[1] / 1e18);
        
        // 验证结果：确保获得的代币A数量与指定的精确输出数量一致
        require(balanceAfter - balanceBefore == 2 ether, "Didn't receive exact token amount");
    }
    
    /**
     * @dev 测试固定输出的代币兑换ETH功能
     * 使用尽可能少的代币A兑换固定数量的ETH
     */
    function testSwapTokensForExactETH() internal {
        console.log("\nTesting swapTokensForExactETH...");
        
        // 授权路由合约使用代币
        tokenA.approve(address(router), 20 ether);
        
        // 设置交易路径
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);
        
        // 记录兑换前的ETH余额
        uint balanceBefore = alice.balance;
        
        // 使用代币兑换精确数量的ETH
        uint[] memory amounts = router.swapTokensForExactETH(
            1 ether,
            20 ether,
            path,
            alice,
            block.timestamp + 1 hours
        );
        
        // 记录兑换后的ETH余额
        uint balanceAfter = alice.balance;
        
        console.log("Swap success:");
        console.log("- Input tokenA amount:", amounts[0] / 1e18);
        console.log("- Received ETH amount:", amounts[1] / 1e18);
        
        // 验证结果：确保获得的ETH数量与指定的精确输出数量一致
        require(balanceAfter - balanceBefore == 1 ether, "Didn't receive exact ETH amount");
    }
    
    /**
     * @dev 测试移除代币流动性功能
     * 燃烧流动性代币，获得池中的代币A和代币B
     */
    function testRemoveLiquidity() internal {
        console.log("\nTesting removeLiquidity...");
        
        // 获取交易对地址
        address pair = factory.getPair(address(tokenA), address(tokenB));
        
        // 获取流动性代币余额（移除一半流动性）
        uint liquidity = ERC20(pair).balanceOf(alice) / 2;
        
        // 授权路由合约使用流动性代币
        ERC20(pair).approve(address(router), liquidity);
        
        // 记录移除前的余额
        uint balanceABefore = tokenA.balanceOf(alice);
        uint balanceBBefore = tokenB.balanceOf(alice);
        
        // 移除流动性
        // 参数说明:
        // 1,2: 代币A和代币B的地址
        // 3: 要燃烧的流动性代币数量
        // 4,5: 期望获得的最小代币A和代币B数量（防止滑点）
        // 6: 接收代币的地址
        // 7: 交易截止时间
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        console.log("Remove liquidity success:");
        console.log("- Burned liquidity tokens:", liquidity / 1e18);
        console.log("- Received tokenA amount:", amountA / 1e18);
        console.log("- Received tokenB amount:", amountB / 1e18);
        
        // 验证结果
        require(tokenA.balanceOf(alice) > balanceABefore, "Didn't receive tokenA");
        require(tokenB.balanceOf(alice) > balanceBBefore, "Didn't receive tokenB");
    }
    
    /**
     * @dev 测试移除ETH流动性功能
     * 燃烧流动性代币，获得池中的代币A和ETH
     */
    function testRemoveLiquidityETH() internal {
        console.log("\nTesting removeLiquidityETH...");
        
        // 获取交易对地址
        address pair = factory.getPair(address(tokenA), address(weth));
        
        // 获取流动性代币余额（移除一半流动性）
        uint liquidity = ERC20(pair).balanceOf(alice) / 2;
        
        // 授权路由合约使用流动性代币
        ERC20(pair).approve(address(router), liquidity);
        
        // 记录移除前的余额
        uint balanceABefore = tokenA.balanceOf(alice);
        uint balanceETHBefore = alice.balance;
        
        // 移除ETH流动性
        // 参数类似removeLiquidity，但将其中一种代币替换为ETH
        (uint amountToken, uint amountETH) = router.removeLiquidityETH(
            address(tokenA),
            liquidity,
            0,
            0,
            alice,
            block.timestamp + 1 hours
        );
        
        console.log("Remove ETH liquidity success:");
        console.log("- Burned liquidity tokens:", liquidity / 1e18);
        console.log("- Received tokenA amount:", amountToken / 1e18);
        console.log("- Received ETH amount:", amountETH / 1e18);
        
        // 验证结果
        require(tokenA.balanceOf(alice) > balanceABefore, "Didn't receive tokenA");
        require(alice.balance > balanceETHBefore, "Didn't receive ETH");
    }
} 
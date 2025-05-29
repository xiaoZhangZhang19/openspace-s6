// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/memefactory/InscriptionFactory.sol";
import "../../src/interfaces/IUniswapV2Router02.sol";
import "../../src/interfaces/IUniswapV2Factory.sol";
import "../../src/interfaces/IUniswapV2Pair.sol";

/**
 * @dev 简化的ERC20接口，用于查询代币余额和铸造参数
 */
interface IERC20Simple {
    function balanceOf(address account) external view returns (uint256);  // 查询余额
    function mintPrice() external view returns (uint256);                // 查询铸造价格
    function perMintAmount() external view returns (uint256);            // 查询每次铸造数量
    function transfer(address to, uint256 amount) external returns (bool); // 转账
    function approve(address spender, uint256 amount) external returns (bool); // 授权
}

/**
 * @title 测试购买铭文代币脚本（模拟破发场景）
 * @dev 这个脚本模拟PEPE代币在Uniswap上价格破发的场景：
 *      1. 首先铸造大量代币
 *      2. 在Uniswap上卖出部分代币导致价格下跌
 *      3. 对比Uniswap和铸造的价格
 *      4. 使用buyMeme智能购买功能（会自动选择更便宜的方式）
 */
contract TestBuyMeme is Script {
    // 已部署的合约地址
    address constant ROUTER_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // Uniswap路由器地址
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH合约地址
    address constant INSCRIPTION_FACTORY = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e; // 铭文工厂合约地址
    address constant PEPE_TOKEN = 0x3Ca8f9C04c7e3E1624Ac2008F92f6F366A869444; // PEPE代币地址
    
    string constant TOKEN_SYMBOL = "PEPE"; // 要测试的代币符号
    
    function run() external {
        // 使用anvil的第一个账户私钥作为测试者
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 获取铭文工厂和代币合约实例
        InscriptionFactory inscriptionFactory = InscriptionFactory(payable(INSCRIPTION_FACTORY));
        IERC20Simple token = IERC20Simple(PEPE_TOKEN);
        
        console.log("===== SIMULATING PRICE DUMP SCENARIO =====");
        
        // 1. 铸造一些代币（如果余额不足）
        uint256 initialBalance = token.balanceOf(deployer);
        console.log("Initial PEPE balance:", initialBalance / 1e18);
        
        if (initialBalance < 5000 ether) {
            // 计算铸造费用
            uint256 mintPrice = token.mintPrice();
            uint256 platformFee = (mintPrice * 10) / 100;
            uint256 factoryFee = (mintPrice * 5) / 100;
            uint256 totalMintCost = mintPrice + platformFee + factoryFee;
            
            // 铸造5次获得更多代币
            console.log("Minting more tokens...");
            for (uint i = 0; i < 5; i++) {
                inscriptionFactory.mintInscription{value: totalMintCost}(TOKEN_SYMBOL);
            }
            
            console.log("New PEPE balance:", token.balanceOf(deployer) / 1e18);
        }
        
        // 获取Uniswap对地址
        address factory = IUniswapV2Router02(ROUTER_ADDRESS).factory();
        address pair = IUniswapV2Factory(factory).getPair(PEPE_TOKEN, WETH_ADDRESS);
        
        if (pair == address(0)) {
            console.log("Warning: Pair does not exist yet");
        } else {
            // 打印初始价格信息
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
            address token0 = IUniswapV2Pair(pair).token0();
            
            uint256 pepeReserve;
            uint256 wethReserve;
            
            if (token0 == PEPE_TOKEN) {
                pepeReserve = reserve0;
                wethReserve = reserve1;
            } else {
                pepeReserve = reserve1;
                wethReserve = reserve0;
            }
            
            if (pepeReserve == 0 || wethReserve == 0) {
                console.log("Warning: Zero reserves in the pair");
            } else {
                console.log("Initial price:");
                console.log("- PEPE reserve:", pepeReserve / 1e18);
                console.log("- WETH reserve:", wethReserve / 1e18);
                console.log("- Price (WETH per PEPE):", (wethReserve * 1e18) / pepeReserve);
                
                // 卖出大量PEPE代币，导致价格下跌
                uint256 sellAmount = 2000 ether; // 卖出2000个PEPE
                
                if (token.balanceOf(deployer) < sellAmount) {
                    console.log("Not enough PEPE tokens to sell");
                } else {
                    console.log("Selling", sellAmount / 1e18, "PEPE tokens to crash the price...");
                    
                    // 授权Router使用代币
                    token.approve(ROUTER_ADDRESS, sellAmount);
                    
                    // 卖出代币，获取ETH
                    address[] memory path = new address[](2);
                    path[0] = PEPE_TOKEN;
                    path[1] = WETH_ADDRESS;
                    
                    try IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForETH(
                        sellAmount,
                        0, // 接受任意数量的ETH
                        path,
                        deployer,
                        block.timestamp + 15 minutes
                    ) {
                        // 获取卖出后的价格
                        (reserve0, reserve1, ) = IUniswapV2Pair(pair).getReserves();
                        
                        if (token0 == PEPE_TOKEN) {
                            pepeReserve = reserve0;
                            wethReserve = reserve1;
                        } else {
                            pepeReserve = reserve1;
                            wethReserve = reserve0;
                        }
                        
                        console.log("Price after dump:");
                        console.log("- PEPE reserve:", pepeReserve / 1e18);
                        console.log("- WETH reserve:", wethReserve / 1e18);
                        console.log("- Price (WETH per PEPE):", (wethReserve * 1e18) / pepeReserve);
                    } catch Error(string memory reason) {
                        console.log("Failed to sell tokens:", reason);
                    } catch {
                        console.log("Failed to sell tokens with unknown error");
                    }
                }
            }
        }
        
        // 尝试通过Uniswap购买代币
        uint256 balanceBefore = token.balanceOf(deployer);
        
        // 构建交易路径：WETH -> PEPE
        address[] memory buyPath = new address[](2);
        buyPath[0] = WETH_ADDRESS;    // 起始代币：WETH
        buyPath[1] = PEPE_TOKEN;      // 目标代币：PEPE
        
        // 通过Uniswap用0.01 ETH购买PEPE代币
        console.log("Buying with 0.01 ETH via Uniswap...");
        
        try IUniswapV2Router02(ROUTER_ADDRESS).swapExactETHForTokens{value: 0.01 ether}(
            0,                           // 接受任意数量的代币（最小输出为0）
            buyPath,                     // 交易路径
            deployer,                    // 代币接收者
            block.timestamp + 15 minutes // 交易截止时间
        ) returns (uint[] memory amounts) {
            console.log("Successfully bought tokens via Uniswap");
            if (amounts.length > 1) {
                console.log("Amount of PEPE tokens received:", amounts[1] / 1e18);
            }
        } catch Error(string memory reason) {
            console.log("Failed to buy via Uniswap:", reason);
        } catch {
            console.log("Failed to buy via Uniswap with unknown error");
        }
        
        // 计算通过Uniswap购买到的代币数量
        uint256 balanceAfter = token.balanceOf(deployer);
        uint256 tokensReceived = balanceAfter - balanceBefore;
        
        // 验证购买是否成功
        if (tokensReceived > 0) {
            console.log("Purchase verification: Successfully received", tokensReceived / 1e18, "PEPE tokens");
        } else {
            console.log("Purchase verification FAILED: No tokens received!");
        }
        
        // 获取当前铸造价格用于比较
        uint256 mintPrice = token.mintPrice();      // 铸造价格
        uint256 perMint = token.perMintAmount();    // 每次铸造数量
        
        // 输出详细的购买结果比较
        console.log("===== PURCHASE COMPARISON =====");
        console.log("Token address:", PEPE_TOKEN);
        console.log("Current token balance:", token.balanceOf(deployer) / 1e18);
        console.log("Tokens received via Uniswap for 0.01 ETH:", tokensReceived / 1e18);
        console.log("Tokens received via mint:", perMint / 1e18);
        console.log("Mint price:", mintPrice / 1e18, "ETH");
        
        // 计算和比较单位代币价格
        if (tokensReceived > 0 && perMint > 0) {
            uint256 uniswapPricePerToken = (0.01 ether * 1e18) / tokensReceived;
            uint256 mintPricePerToken = (mintPrice * 1e18) / perMint;
            
            console.log("Effective price per token (Uniswap):", uniswapPricePerToken, "wei");
            console.log("Effective price per token (minting):", mintPricePerToken, "wei");
            
            // 判断哪种购买方式更优惠
            if (mintPricePerToken < uniswapPricePerToken) {
                console.log(">>> Mint price is better than Uniswap price");
            } else {
                console.log(">>> Uniswap price is better than mint price (PRICE DUMP SUCCESSFUL)");
                
                // 尝试使用工厂的智能购买功能
                // 工厂会自动选择最优的购买方式（应该选择Uniswap）
                console.log("Trying to buy via buyMeme function (should choose Uniswap)...");
                
                uint256 buyMemeBalanceBefore = token.balanceOf(deployer);
                
                try inscriptionFactory.buyMeme{value: 0.01 ether}(TOKEN_SYMBOL, 0, block.timestamp + 15 minutes) {
                    uint256 buyMemeBalanceAfter = token.balanceOf(deployer);
                    uint256 buyMemeTokensReceived = buyMemeBalanceAfter - buyMemeBalanceBefore;
                    
                    console.log(">>> Successfully bought tokens via buyMeme");
                    
                    if (buyMemeTokensReceived > 0) {
                        console.log(">>> buyMeme verification: Received", buyMemeTokensReceived / 1e18, "PEPE tokens");
                        
                        // 比较两种方式获得的代币数量
                        if (buyMemeTokensReceived > tokensReceived) {
                            console.log(">>> buyMeme provided MORE tokens than direct Uniswap swap");
                        } else if (buyMemeTokensReceived < tokensReceived) {
                            console.log(">>> buyMeme provided FEWER tokens than direct Uniswap swap");
                        } else {
                            console.log(">>> buyMeme provided SAME amount of tokens as direct Uniswap swap");
                        }
                    } else {
                        console.log(">>> buyMeme verification FAILED: No tokens received!");
                    }
                } catch Error(string memory reason) {
                    console.log(">>> Failed to buy tokens:", reason);
                } catch {
                    console.log(">>> Failed to buy tokens with unknown error");
                }
            }
        }
        
        vm.stopBroadcast();
    }
} 
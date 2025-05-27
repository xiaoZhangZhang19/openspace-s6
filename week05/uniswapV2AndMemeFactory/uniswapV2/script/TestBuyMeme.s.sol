// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/memefactory/InscriptionFactory.sol";
import "../src/interfaces/IUniswapV2Router02.sol";

interface IERC20Simple {
    function balanceOf(address account) external view returns (uint256);
    function mintPrice() external view returns (uint256);
    function perMintAmount() external view returns (uint256);
}

contract TestBuyMeme is Script {
    // Deployed contract addresses
    address constant ROUTER_ADDRESS = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0; // Uniswap Router
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH
    address constant INSCRIPTION_FACTORY = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e; // Meme Factory
    address constant PEPE_TOKEN = 0x3Ca8f9C04c7e3E1624Ac2008F92f6F366A869444; // PEPE token
    
    string constant TOKEN_SYMBOL = "PEPE";
    
    function run() external {
        // Use the first account private key from anvil
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Try to buy via Uniswap directly
        uint256 balanceBefore = IERC20Simple(PEPE_TOKEN).balanceOf(deployer);
        
        address[] memory path = new address[](2);
        path[0] = WETH_ADDRESS;
        path[1] = PEPE_TOKEN;
        
        IUniswapV2Router02(ROUTER_ADDRESS).swapExactETHForTokens{value: 0.01 ether}(
            0, // accept any amount of tokens
            path,
            deployer,
            block.timestamp + 15 minutes
        );
        
        uint256 balanceAfter = IERC20Simple(PEPE_TOKEN).balanceOf(deployer);
        uint256 tokensReceived = balanceAfter - balanceBefore;
        
        // 2. Get the current mint price for comparison
        InscriptionFactory inscriptionFactory = InscriptionFactory(payable(INSCRIPTION_FACTORY));
        
        // Get inscription token parameters from the token contract
        IERC20Simple token = IERC20Simple(PEPE_TOKEN);
        
        uint256 mintPrice = token.mintPrice();
        uint256 perMint = token.perMintAmount();
        
        // Print out the results to compare
        console.log("===== PURCHASE COMPARISON =====");
        console.log("Token address:", PEPE_TOKEN);
        console.log("Token balance:", token.balanceOf(deployer) / 1e18);
        console.log("Tokens received via Uniswap for 0.01 ETH:", tokensReceived / 1e18);
        console.log("Tokens received via mint:", perMint / 1e18);
        console.log("Mint price:", mintPrice / 1e18, "ETH");
        
        if (tokensReceived > 0 && perMint > 0) {
            console.log("Effective price per token (Uniswap):", (0.01 ether * 1e18) / tokensReceived, "wei");
            console.log("Effective price per token (minting):", (mintPrice * 1e18) / perMint, "wei");
            
            if ((mintPrice * 1e18) / perMint < (0.01 ether * 1e18) / tokensReceived) {
                console.log("Mint price is better than Uniswap price");
            } else {
                console.log("Uniswap price is better than mint price");
                
                // Try to buy tokens via the factory's buyMeme function
                try inscriptionFactory.buyMeme{value: 0.01 ether}(TOKEN_SYMBOL, 0, block.timestamp + 15 minutes) {
                    console.log("Successfully bought tokens via buyMeme");
                } catch Error(string memory reason) {
                    console.log("Failed to buy tokens:", reason);
                }
            }
        }
        
        vm.stopBroadcast();
    }
} 
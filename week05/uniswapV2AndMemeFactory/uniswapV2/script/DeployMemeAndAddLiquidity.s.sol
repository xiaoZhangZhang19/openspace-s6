// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/memefactory/InscriptionFactory.sol";

contract DeployMemeAndAddLiquidity is Script {
    // Deployed contract addresses
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Uniswap Factory
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH
    address constant INSCRIPTION_FACTORY = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e; // Meme Factory
    
    // Inscription token parameters
    string constant TOKEN_SYMBOL = "PEPE";
    uint256 constant TOTAL_SUPPLY = 1000000 ether; // 1,000,000 tokens
    uint256 constant PER_MINT = 1000 ether;       // 1,000 tokens per mint
    uint256 constant MINT_PRICE = 0.1 ether;      // 0.1 ETH per mint
    
    function run() external {
        // Use the first account private key from anvil
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get inscription factory instance
        InscriptionFactory inscriptionFactory = InscriptionFactory(payable(INSCRIPTION_FACTORY));
        
        // 1. Deploy inscription token
        inscriptionFactory.deployInscription{value: 0.01 ether}(
            TOKEN_SYMBOL,
            TOTAL_SUPPLY,
            PER_MINT,
            MINT_PRICE
        );
        
        // 2. Mint tokens
        uint256 platformFee = (MINT_PRICE * 10) / 100;
        uint256 factoryFee = (MINT_PRICE * 5) / 100;
        uint256 totalMintCost = MINT_PRICE + platformFee + factoryFee;
        
        // Mint 5 times
        for (uint i = 0; i < 5; i++) {
            inscriptionFactory.mintInscription{value: totalMintCost}(TOKEN_SYMBOL);
        }
        
        // 3. Transfer ETH to factory for adding liquidity
        (bool success, ) = payable(INSCRIPTION_FACTORY).call{value: 2 ether}("");
        require(success, "ETH transfer failed");
        
        // 4. Add liquidity with only 1000 tokens (the amount we have)
        inscriptionFactory.buyAndAddLiquidity(TOKEN_SYMBOL, 0.2 ether);
        
        vm.stopBroadcast();
    }
} 
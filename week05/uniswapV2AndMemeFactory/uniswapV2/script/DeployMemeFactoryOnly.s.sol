// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/memefactory/InscriptionFactory.sol";

contract DeployMemeFactoryOnly is Script {
    // Deployed Uniswap contract addresses
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
    address payable constant ROUTER_ADDRESS = payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);
    
    function run() external {
        // Use the first account private key from anvil
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Inscription Factory
        InscriptionFactory inscriptionFactory = new InscriptionFactory();
        
        // Configure Uniswap router and WETH
        inscriptionFactory.setUniswapRouterDirect(ROUTER_ADDRESS);
        inscriptionFactory.setWeth(WETH_ADDRESS);
        inscriptionFactory.setFee(0.01 ether); // Set to 0.01 ETH
        
        vm.stopBroadcast();
    }
} 
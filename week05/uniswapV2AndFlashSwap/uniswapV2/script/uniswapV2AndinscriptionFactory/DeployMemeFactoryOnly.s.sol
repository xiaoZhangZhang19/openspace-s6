// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../../src/memefactory/InscriptionFactory.sol";

/**
 * @title 仅部署铭文工厂脚本
 * @dev 这个脚本用于在已有Uniswap V2部署的基础上，单独部署铭文代币工厂合约
 * @notice 使用前确保Uniswap V2的核心合约已经部署完成
 */
contract DeployMemeFactoryOnly is Script {
    // 已部署的Uniswap合约地址
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Uniswap V2工厂合约地址
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH合约地址
    address payable constant ROUTER_ADDRESS = payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0); // Uniswap V2路由器地址
    
    function run() external {
        // 使用anvil的第一个账户私钥作为部署者
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署铭文工厂合约
        // 工厂合约会在构造函数中自动部署铭文代币的实现合约
        InscriptionFactory inscriptionFactory = new InscriptionFactory();
        
        // 配置Uniswap路由器和WETH地址
        // 设置路由器地址（直接设置，不调用WETH函数避免可能的错误）
        inscriptionFactory.setUniswapRouterDirect(ROUTER_ADDRESS);
        // 手动设置WETH地址
        inscriptionFactory.setWeth(WETH_ADDRESS);
        // 设置部署铭文代币的费用为0.01 ETH
        inscriptionFactory.setFee(0.01 ether);
        
        vm.stopBroadcast();
    }
} 
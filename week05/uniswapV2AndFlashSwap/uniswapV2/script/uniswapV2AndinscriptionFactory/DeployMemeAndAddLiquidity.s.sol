// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../../src/memefactory/InscriptionFactory.sol";

/**
 * @title 部署铭文代币并添加流动性脚本
 * @dev 这个脚本演示了完整的铭文代币生命周期：
 *      1. 部署铭文代币
 *      2. 铸造一些代币
 *      3. 为代币添加初始流动性到Uniswap
 * @notice 运行前确保铭文工厂已经部署并配置完成
 */
contract DeployMemeAndAddLiquidity is Script {
    // 已部署的合约地址
    address constant FACTORY_ADDRESS = 0x5FbDB2315678afecb367f032d93F642f64180aa3; // Uniswap工厂合约地址
    address constant WETH_ADDRESS = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512; // WETH合约地址
    address constant INSCRIPTION_FACTORY = 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e; // 铭文工厂合约地址
    
    // 铭文代币参数配置
    string constant TOKEN_SYMBOL = "PEPE";               // 代币符号
    uint256 constant TOTAL_SUPPLY = 1000000 ether;      // 总供应量：1,000,000 代币
    uint256 constant PER_MINT = 1000 ether;             // 每次铸造数量：1,000 代币
    uint256 constant MINT_PRICE = 0.1 ether;            // 铸造价格：0.1 ETH
    
    function run() external {
        // 使用anvil的第一个账户私钥作为部署者
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 获取铭文工厂合约实例
        InscriptionFactory inscriptionFactory = InscriptionFactory(payable(INSCRIPTION_FACTORY));
        
        // 1. 部署铭文代币
        // 支付0.01 ETH的部署费用
        inscriptionFactory.deployInscription{value: 0.01 ether}(
            TOKEN_SYMBOL,    // 代币符号
            TOTAL_SUPPLY,    // 总供应量
            PER_MINT,        // 每次铸造数量
            MINT_PRICE       // 铸造价格
        );
        
        // 2. 铸造代币
        // 计算铸造费用结构
        uint256 platformFee = (MINT_PRICE * 10) / 100;  // 平台费用：10%
        uint256 factoryFee = (MINT_PRICE * 5) / 100;    // 工厂费用：5%（用于流动性）
        uint256 totalMintCost = MINT_PRICE + platformFee + factoryFee; // 总费用
        
        // 铸造5次，总共获得5000个代币
        for (uint i = 0; i < 5; i++) {
            inscriptionFactory.mintInscription{value: totalMintCost}(TOKEN_SYMBOL);
        }
        
        // 3. 向工厂转入ETH用于添加流动性
        // 为添加流动性操作提供额外的ETH资金
        (bool success, ) = payable(INSCRIPTION_FACTORY).call{value: 2 ether}("");
        require(success, "ETH transfer failed");
        
        // 4. 添加流动性
        // 使用0.2 ETH的资金来购买代币并添加流动性
        // 这将创建初始的Uniswap交易对并设定初始价格
        inscriptionFactory.buyAndAddLiquidity(TOKEN_SYMBOL, 0.2 ether);
        
        vm.stopBroadcast();
    }
} 
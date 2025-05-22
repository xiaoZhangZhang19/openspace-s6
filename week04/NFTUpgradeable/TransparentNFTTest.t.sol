// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {TransparentNFTV1} from "../../src/Transparent/NFT/TransparentNFTV1.sol";
import {TransparentNFTV2} from "../../src/Transparent/NFT/TransparentNFTV2.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract TransparentNFTTest is Test {
    // 实现合约V1
    TransparentNFTV1 public nftV1Implementation;
    // 实现合约V2
    TransparentNFTV2 public nftV2Implementation;
    // 透明代理合约
    TransparentUpgradeableProxy public proxy;
    // 管理员地址
    address public owner;
    // 用户地址（EOA）
    address public user;
    
    // 管理员存储插槽
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {
        // 设置管理员地址和用户地址
        owner = address(this);
        user = makeAddr("user");
        
        // 部署实现合约
        nftV1Implementation = new TransparentNFTV1();
        nftV2Implementation = new TransparentNFTV2();
        
        // 编码初始化调用
        bytes memory initData = abi.encodeWithSelector(
            TransparentNFTV1.initialize.selector,
            owner
        );
        
        // 部署透明代理合约
        proxy = new TransparentUpgradeableProxy(
            address(nftV1Implementation),
            owner,
            initData
        );
    }

    // 测试铸造NFT（V1版本）
    function testMint() public {
        // 获取实际的代理合约
        TransparentNFTV1 nftProxy = TransparentNFTV1(address(proxy));
        
        nftProxy.safeMint(user, "ipfs://QmTest");
        
        // 验证所有权
        assertEq(nftProxy.ownerOf(0), user, unicode"NFT应该属于用户");
        // 验证URI
        assertEq(nftProxy.tokenURI(0), "ipfs://QmTest", unicode"Token URI应该匹配");
    }

    // 测试升级
    function testUpgrade() public {
        // 获取实际的管理员地址
        bytes32 data = vm.load(address(proxy), _ADMIN_SLOT);
        // 将管理员地址转换为地址类型
        address adminAddress = address(uint160(uint256(data)));
        // 打印代理地址、管理员地址和拥有者地址
        console2.log("Proxy address:", address(proxy));
        console2.log("Admin address:", adminAddress);
        console2.log("Owner address:", owner);
        
        // 使用V1版本铸造NFT
        TransparentNFTV1 nftProxyV1 = TransparentNFTV1(address(proxy));
        nftProxyV1.safeMint(user, "ipfs://QmTest");
        
        // 验证NFT已铸造
        assertEq(nftProxyV1.ownerOf(0), user, unicode"升级前NFT应该属于用户");
        
        // 将管理员地址转换为ProxyAdmin类型
        ProxyAdmin admin = ProxyAdmin(adminAddress);
        
        // 调用正确的管理员合约进行升级
        admin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(nftV2Implementation),
            ""
        );
        
        // 验证升级后的版本
        TransparentNFTV2 nftProxyV2 = TransparentNFTV2(address(proxy));
        
        // 验证数据保持不变
        assertEq(nftProxyV2.ownerOf(0), user, unicode"升级后NFT所有权应该保持不变");
        assertEq(nftProxyV2.tokenURI(0), "ipfs://QmTest", unicode"升级后Token URI应该保持不变");
        
        // 测试V2新增功能
        // 设置稀有度
        nftProxyV2.setRarity(0, 100);
        assertEq(nftProxyV2.getRarity(0), 100, unicode"稀有度应该被设置为100");
        
        // 测试批量铸造
        string[] memory uris = new string[](2);
        uris[0] = "ipfs://QmBatchTest1";
        uris[1] = "ipfs://QmBatchTest2";
        
        nftProxyV2.batchMint(user, uris);
        
        // 验证批量铸造结果
        assertEq(nftProxyV2.ownerOf(1), user, unicode"批量铸造的NFT 1应该属于用户");
        assertEq(nftProxyV2.ownerOf(2), user, unicode"批量铸造的NFT 2应该属于用户");
        assertEq(nftProxyV2.tokenURI(1), "ipfs://QmBatchTest1", unicode"批量铸造的Token 1 URI应该匹配");
        assertEq(nftProxyV2.tokenURI(2), "ipfs://QmBatchTest2", unicode"批量铸造的Token 2 URI应该匹配");
    }
} 
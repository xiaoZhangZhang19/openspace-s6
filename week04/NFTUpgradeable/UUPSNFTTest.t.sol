// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {UUPSNFTV1} from "../../src/UUPS/NFT/UUPSNFTV1.sol";
import {UUPSNFTV2} from "../../src/UUPS/NFT/UUPSNFTV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UUPSNFTTest is Test {
    // 实现合约V1
    UUPSNFTV1 public nftV1Implementation;
    // 实现合约V2
    UUPSNFTV2 public nftV2Implementation;
    // 代理合约
    ERC1967Proxy public proxy;
    // 管理员地址
    address public owner;
    // 用户地址（EOA）
    address public user;

    function setUp() public {
        // 设置管理员地址
        owner = address(this);
        // 创建用户EOA地址
        user = makeAddr("user");
        
        // 部署实现合约
        nftV1Implementation = new UUPSNFTV1();
        
        // 编码初始化调用
        bytes memory initData = abi.encodeWithSelector(
            UUPSNFTV1.initialize.selector,
            owner
        );
        
        // 部署代理合约
        proxy = new ERC1967Proxy(
            address(nftV1Implementation),
            initData
        );
    }

    // 测试铸造NFT（V1版本）
    function testMint() public {
        // 获取实际的代理合约
        UUPSNFTV1 nftProxy = UUPSNFTV1(address(proxy));
        // 铸造NFT给用户（EOA）
        nftProxy.safeMint(user, "ipfs://QmTest");
        // 验证所有权
        assertEq(nftProxy.ownerOf(0), user, unicode"NFT应该属于用户");
        // 验证URI
        assertEq(nftProxy.tokenURI(0), "ipfs://QmTest", unicode"Token URI应该匹配");
    }

    // 测试升级
    function testUpgrade() public {
        // 使用V1版本铸造NFT
        UUPSNFTV1 nftProxyV1 = UUPSNFTV1(address(proxy));
        nftProxyV1.safeMint(user, "ipfs://QmTest");
        
        // 部署V2实现
        nftV2Implementation = new UUPSNFTV2();
        
        // 升级到V2
        nftProxyV1.upgradeToAndCall(address(nftV2Implementation), "");
        
        // 验证升级后的版本
        UUPSNFTV2 nftProxyV2 = UUPSNFTV2(address(proxy));
        
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
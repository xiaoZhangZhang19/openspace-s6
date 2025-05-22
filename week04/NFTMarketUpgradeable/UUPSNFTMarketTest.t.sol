// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {UUPSNFTMarketV1} from "../../src/UUPS/NFTMarket/UUPSNFTMarketV1.sol";
import {UUPSNFTMarketV2} from "../../src/UUPS/NFTMarket/UUPSNFTMarketV2.sol";
import {MarketNFT} from "../../src/UUPS/NFTMarket/MarketNFT.sol";
import {MarketToken} from "../../src/UUPS/NFTMarket/MarketToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UUPSNFTMarketTest is Test {
    // 测试数据结构，用于组织相关数据，减少局部变量数量
    struct TestData {
        uint256 tokenId;
        uint256 price;
        uint256 deadline;
        bytes32 domainSeparator;
        bytes32 structHash;
        bytes32 digest;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    // 实现合约V1
    UUPSNFTMarketV1 public NFTMarketV1Implementation;
    // 实现合约V2   
    UUPSNFTMarketV2 public NFTMarketV2Implementation;
    // 代理合约
    ERC1967Proxy public proxy;
    // 管理员地址
    address public owner;
    // 管理员私钥
    uint256 public ownerPrivateKey;
    // NFT合约
    MarketNFT public nft;
    // Token合约
    MarketToken public token;
    // NFT持有者地址和私钥
    address public nftHolder;
    uint256 public nftHolderPrivateKey;
    // 买家地址
    address public buyer;

    function setUp() public {
        // 设置管理员地址
        ownerPrivateKey = 0xB0B;
        owner = vm.addr(ownerPrivateKey);
        vm.startPrank(owner);
        
        // 部署实现合约
        NFTMarketV1Implementation = new UUPSNFTMarketV1();
        NFTMarketV2Implementation = new UUPSNFTMarketV2();
        
        // 编码初始化调用
        bytes memory initData = abi.encodeWithSelector(
            UUPSNFTMarketV1.initialize.selector,
            owner
        );

        // 部署ERC1967代理合约
        proxy = new ERC1967Proxy(
            address(NFTMarketV1Implementation),
            initData
        );

        // 部署NFT和Token合约
        nft = new MarketNFT();
        token = new MarketToken(1000000 * 10**18); // 初始供应量1,000,000个代币

        vm.stopPrank();

        // 设置NFT持有者
        nftHolderPrivateKey = 0xA11CE;
        nftHolder = vm.addr(nftHolderPrivateKey);

        // 设置买家
        buyer = makeAddr("buyer");

        // 给NFT持有者铸造NFT
        vm.startPrank(owner);
        nft.mintNFT(nftHolder);

        // 给买家转移一些代币
        token.transfer(buyer, 100 * 10**18);
        vm.stopPrank();

        console.log("Proxy address:", address(proxy));
        console.log("NFT Market V1 implementation:", address(NFTMarketV1Implementation));
        console.log("NFT Market V2 implementation:", address(NFTMarketV2Implementation));
    }

    function testDeploy() public {
        // 获取实际的代理合约
        UUPSNFTMarketV1 NFTMarketProxy = UUPSNFTMarketV1(payable(address(proxy)));
        // 调用旧函数
        NFTMarketProxy.addOldFunction();
        assertEq(NFTMarketProxy.getUpGradeTest(), 1, "upgrade test value should be 1");
    }

    // 辅助函数：升级合约
    function _upgradeContract() internal returns (UUPSNFTMarketV2) {
        console.log("Start upgrade test");
        
        // 使用UUPS模式升级合约，需要通过代理合约调用实现合约的upgradeToAndCall方法
        vm.startPrank(owner);
        
        // 将代理转换为V1，并调用其upgradeToAndCall方法
        UUPSNFTMarketV1 marketV1 = UUPSNFTMarketV1(payable(address(proxy)));
        marketV1.upgradeToAndCall(address(NFTMarketV2Implementation), "");
        
        vm.stopPrank();
        
        console.log("Upgrade successful");

        // 获取V2代理合约实例
        UUPSNFTMarketV2 marketV2 = UUPSNFTMarketV2(payable(address(proxy)));

        // 测试新增的函数
        console.log("Testing new function");
        marketV2.addNewFunction();
        assertEq(marketV2.getUpGradeTest(), 2, "upgrade test value should be 2");

        return marketV2;
    }

    // 辅助函数：准备NFT上架数据
    function _prepareListingData(UUPSNFTMarketV2 marketV2) internal returns (TestData memory) {
        TestData memory data;
        
        // NFT持有者授权市场合约操作其所有NFT
        console.log("NFT holder approving market contract");
        vm.startPrank(nftHolder);
        nft.setApprovalForAll(address(proxy), true);
        vm.stopPrank();

        // 创建签名上架NFT的信息
        data.tokenId = 1;
        data.price = 10 * 10**18; // 10个代币
        data.deadline = block.timestamp + 1 hours;
        
        console.log("Getting domain separator");
        // 获取域分隔符
        data.domainSeparator = marketV2.DOMAIN_SEPARATOR();
        
        console.log("Calculating message digest for listing");
        // 计算消息摘要
        data.structHash = keccak256(abi.encode(
            marketV2.LIST_WITH_SIGNATURE_TYPEHASH(),
            data.tokenId,
            data.price,
            marketV2.nonces(nftHolder),
            data.deadline
        ));
        
        data.digest = keccak256(abi.encodePacked(
            "\x19\x01",
            data.domainSeparator,
            data.structHash
        ));
        
        console.log("Creating signature for listing");
        // 使用NFT持有者的私钥签名
        (data.v, data.r, data.s) = vm.sign(nftHolderPrivateKey, data.digest);

        return data;
    }

    // 辅助函数：使用签名上架NFT
    function _listNFT(UUPSNFTMarketV2 marketV2, TestData memory data) internal {
        console.log("Listing NFT with signature");
        // 使用签名上架NFT
        try marketV2.listWithSignature(
            address(nft),
            data.tokenId,
            address(token),
            data.price,
            data.deadline,
            data.v, data.r, data.s
        ) {
            console.log("Listing successful");
        } catch Error(string memory reason) {
            console.log("Listing failed:", reason);
            revert(reason);
        } catch {
            console.log("Listing failed, unknown reason");
            revert("Unknown error during listing");
        }
        
        // 验证NFT是否已转移到市场合约
        console.log("Verifying NFT transfer to market contract");
        assertEq(nft.ownerOf(data.tokenId), address(proxy), "NFT should be transferred to market contract");
    }

    // 辅助函数：创建白名单签名并购买NFT
    function _buyNFT(UUPSNFTMarketV2 marketV2, TestData memory data) internal {
        // 买家授权市场合约使用其代币
        console.log("Buyer approving market contract");
        vm.startPrank(buyer);
        token.approve(address(proxy), data.price);
        vm.stopPrank();
        
        // 现在创建白名单签名，需要使用合约所有者的私钥
        console.log("Creating whitelist signature for buyer");
        // 计算消息摘要
        bytes32 whitelistStructHash = keccak256(abi.encode(
            marketV2.WHITELIST_TYPEHASH(),
            buyer,
            marketV2.nonces(buyer),
            data.deadline
        ));
        
        bytes32 whitelistDigest = keccak256(abi.encodePacked(
            "\x19\x01",
            data.domainSeparator,
            whitelistStructHash
        ));
        
        // 使用所有者私钥签名
        (uint8 wv, bytes32 wr, bytes32 ws) = vm.sign(ownerPrivateKey, whitelistDigest);
        
        console.log("Buyer purchasing NFT");
        // 买家购买NFT
        vm.startPrank(buyer);
        try marketV2.permitBuy(
            address(nft),
            address(token),
            data.tokenId,
            data.deadline,
            wv, wr, ws
        ) {
            console.log("Purchase successful");
        } catch Error(string memory reason) {
            console.log("Purchase failed:", reason);
            revert(reason);
        } catch {
            console.log("Purchase failed, unknown reason");
            revert("Unknown error during purchase");
        }
        
        // 验证NFT是否已转移给买家
        console.log("Verifying NFT transfer to buyer");
        assertEq(nft.ownerOf(data.tokenId), buyer, "NFT should be transferred to buyer");
        
        // 验证代币是否已转移给卖家
        console.log("Verifying token transfer to seller");
        assertEq(token.balanceOf(nftHolder), data.price, "Tokens should be transferred to seller");
        vm.stopPrank();
    }

    function testUpgradeAndListWithSignature() public {
        // 1. 升级合约
        UUPSNFTMarketV2 marketV2 = _upgradeContract();
        
        // 2. 准备NFT上架数据
        TestData memory data = _prepareListingData(marketV2);
        
        // 3. 使用签名上架NFT
        _listNFT(marketV2, data);
        
        // 4. 创建白名单签名并购买NFT
        _buyNFT(marketV2, data);
    }
} 
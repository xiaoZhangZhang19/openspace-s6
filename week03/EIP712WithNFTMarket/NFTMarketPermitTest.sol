// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../src/NFT/NFTMarket.sol";
import "../src/NFT/MarketNFT.sol";
import "../src/NFT/MarketToken.sol";

contract NFTMarketPermitTest is Test {
    NFTMarket public market;
    MarketNFT public nft;
    MarketToken public token;
    
    address public owner;
    address public seller;
    address public buyer;
    uint256 private constant OWNER_PRIVATE_KEY = 1;
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    
    function setUp() public {
        // 部署合约
        market = new NFTMarket();
        nft = new MarketNFT();
        token = new MarketToken(INITIAL_BALANCE);
        
        // 设置账户
        owner = vm.addr(OWNER_PRIVATE_KEY);  // 使用固定的私钥生成owner地址
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        
        // 转移合约所有权给owner
        market.transferOwnership(owner);
        
        // 给买家一些代币
        token.transfer(buyer, 100 ether);
        
        // 给卖家铸造一个NFT
        nft.mintNFT(seller);  // 使用正确的函数名
        vm.startPrank(seller);
        nft.approve(address(market), 1);  // tokenId从1开始
        vm.stopPrank();
    }
    
    function testPermitBuy() public {
        // 上架NFT
        vm.startPrank(seller);
        market.list(address(nft), 1, address(token), 10 ether);
        vm.stopPrank();
        
        // 准备签名数据
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 WHITELIST_TYPEHASH = market.WHITELIST_TYPEHASH();
        uint256 nonce = market.nonces(buyer);
        
        // 构造签名数据
        bytes32 structHash = keccak256(abi.encode(
            WHITELIST_TYPEHASH,
            buyer,
            nonce,
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        // 使用owner私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        // 买家授权token给市场合约
        vm.startPrank(buyer);
        token.approve(address(market), 10 ether);
        
        // 买家使用permitBuy购买NFT
        market.permitBuy(
            address(nft),
            address(token),
            1,  // tokenId从1开始
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();
        
        // 验证购买结果
        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), 10 ether);
    }
    
    function testPermitBuyWithExpiredSignature() public {
        // 上架NFT
        vm.startPrank(seller);
        market.list(address(nft), 1, address(token), 10 ether);
        vm.stopPrank();
        
        // 准备过期的签名数据
        uint256 deadline = block.timestamp - 1;
        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 WHITELIST_TYPEHASH = market.WHITELIST_TYPEHASH();
        uint256 nonce = market.nonces(buyer);
        
        // 构造签名数据
        bytes32 structHash = keccak256(abi.encode(
            WHITELIST_TYPEHASH,
            buyer,
            nonce,
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        // 使用owner私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, digest);
        
        // 买家授权token给市场合约
        vm.startPrank(buyer);
        token.approve(address(market), 10 ether);
        
        // 尝试使用过期的签名购买NFT，应该失败
        vm.expectRevert("NFTMarket: signature expired");
        market.permitBuy(
            address(nft),
            address(token),
            1,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();
    }
    
    function testPermitBuyWithInvalidSignature() public {
        // 上架NFT
        vm.startPrank(seller);
        market.list(address(nft), 1, address(token), 10 ether);
        vm.stopPrank();
        
        // 准备签名数据
        uint256 deadline = block.timestamp + 1 hours;
        bytes32 domainSeparator = market.DOMAIN_SEPARATOR();
        bytes32 WHITELIST_TYPEHASH = market.WHITELIST_TYPEHASH();
        uint256 nonce = market.nonces(buyer);
        
        // 构造签名数据
        bytes32 structHash = keccak256(abi.encode(
            WHITELIST_TYPEHASH,
            buyer,
            nonce,
            deadline
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        // 使用非owner的私钥签名
        uint256 invalidPrivateKey = 2;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(invalidPrivateKey, digest);
        
        // 买家授权token给市场合约
        vm.startPrank(buyer);
        token.approve(address(market), 10 ether);
        
        // 尝试使用无效签名购买NFT，应该失败
        vm.expectRevert("NFTMarket: invalid signature");
        market.permitBuy(
            address(nft),
            address(token),
            1,
            deadline,
            v,
            r,
            s
        );
        vm.stopPrank();
    }
} 
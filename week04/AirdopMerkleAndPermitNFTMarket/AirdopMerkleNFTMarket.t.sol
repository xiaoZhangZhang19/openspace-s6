// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "forge-std/Test.sol";
import "../../src/NFT/AirdopMerkleNFTMarket.sol";
import "../../src/NFT/MarketNFT.sol";
import "../../src/NFT/MarketToken.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarketTest is Test {
    AirdopMerkleNFTMarket public market;
    MarketNFT public nft;
    MarketToken public token;
    
    address public owner;
    address public seller;
    address public buyer;
    address public whitelistedUser;
    uint256 public whitelistedUserPrivateKey = 0xA11CE;
    
    bytes32 public merkleRoot;
    bytes32[] public merkleProof;
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    
    function setUp() public {
        // 设置测试账户
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        whitelistedUser = vm.addr(whitelistedUserPrivateKey);
        
        // 部署合约
        vm.startPrank(owner);
        nft = new MarketNFT();
        token = new MarketToken(INITIAL_SUPPLY);
        vm.stopPrank();
        
        // 构建Merkle树
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(whitelistedUser));
        leaves[1] = keccak256(abi.encodePacked(buyer));
        
        // 使用 OpenZeppelin 的 MerkleProof 库生成 root
        merkleRoot = _computeRoot(leaves);
        
        // 部署市场合约
        market = new AirdopMerkleNFTMarket(merkleRoot);
        
        // 为测试准备NFT和代币
        vm.startPrank(owner);
        nft.mintNFT(seller);
        token.transfer(seller, NFT_PRICE * 2);
        token.transfer(whitelistedUser, NFT_PRICE);
        vm.stopPrank();
        
        // 生成白名单用户的Merkle证明
        merkleProof = _generateProof(leaves, 0);
        
        // 验证 proof 是否正确
        bytes32 leaf = keccak256(abi.encodePacked(whitelistedUser));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof generated");
    }
    
    function test_ListNFT() public {
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, address(token), NFT_PRICE);
        vm.stopPrank();
        
        // 验证NFT已转移到市场合约
        assertEq(nft.ownerOf(1), address(market));
    }
    
    function test_ClaimNFTWithMulticall() public {
        // 准备NFT上架
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, address(token), NFT_PRICE);
        vm.stopPrank();
        
        // 准备permit签名
        vm.startPrank(whitelistedUser);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(whitelistedUser);
        uint256 value = NFT_PRICE / 2;
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            whitelistedUser,
            address(market),
            value,
            nonce,
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedUserPrivateKey, digest);
        
        // 准备multicall数据
        bytes[] memory data = new bytes[](2);
        // 准备permitPrePay数据，传入multicall中相当于
        // address.delegatecall(abi.encodeWithSelector(market.permitPrePay.selector, 
        // address(token), address(market), value, deadline, v, r, s))
        data[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            address(token),
            address(market),
            value,
            deadline,
            v,
            r,
            s
        );
        // 准备claimNFT数据，传入multicall中相当于
        // address.delegatecall(abi.encodeWithSelector(market.claimNFT.selector,
        // address(nft), address(token), 1, whitelistedUser, merkleProof))
        data[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            address(nft),
            address(token),
            1,
            whitelistedUser,
            merkleProof
        );
        
        // 执行multicall
        market.multicall(data);
        vm.stopPrank();
        
        // 验证结果
        assertEq(nft.ownerOf(1), whitelistedUser);
        assertEq(token.balanceOf(whitelistedUser), NFT_PRICE / 2);
        assertEq(token.balanceOf(seller), NFT_PRICE * 2 + NFT_PRICE / 2);
    }
    
    function test_PermitPrePayAndClaimNFT_Separate() public {
        // 上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, address(token), NFT_PRICE);
        vm.stopPrank();

        // permit 授权
        vm.startPrank(whitelistedUser);
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(whitelistedUser);
        uint256 value = NFT_PRICE / 2;
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            whitelistedUser,
            address(market),
            value,
            nonce,
            deadline
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(whitelistedUserPrivateKey, digest);
        market.permitPrePay(address(token), address(market), value, deadline, v, r, s);
        // claimNFT
        market.claimNFT(address(nft), address(token), 1, whitelistedUser, merkleProof);
        vm.stopPrank();
        // 验证
        assertEq(nft.ownerOf(1), whitelistedUser);
        assertEq(token.balanceOf(whitelistedUser), NFT_PRICE / 2);
        assertEq(token.balanceOf(seller), NFT_PRICE * 2 + NFT_PRICE / 2);
    }
    
    function test_RevertWhen_NonWhitelistedUserClaim() public {
        // 准备NFT上架
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, address(token), NFT_PRICE);
        vm.stopPrank();
        
        // 非白名单用户尝试购买
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        vm.expectRevert("MerkleDistributor: Invalid proof.");
        market.claimNFT(address(nft), address(token), 1, buyer, merkleProof);
        vm.stopPrank();
    }
    
    function test_RevertWhen_InvalidMerkleProof() public {
        // 准备NFT上架
        vm.startPrank(seller);
        nft.approve(address(market), 1);
        market.list(address(nft), 1, address(token), NFT_PRICE);
        vm.stopPrank();
        
        // 使用错误的Merkle证明
        bytes32[] memory wrongProof = new bytes32[](1);
        wrongProof[0] = bytes32(0);
        
        vm.startPrank(whitelistedUser);
        token.approve(address(market), NFT_PRICE / 2);
        vm.expectRevert("MerkleDistributor: Invalid proof.");
        market.claimNFT(address(nft), address(token), 1, whitelistedUser, wrongProof);
        vm.stopPrank();
    }
    
    // 辅助函数：使用 OpenZeppelin 的 MerkleProof 库生成 root
    function _computeRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];
        
        bytes32[] memory layer = leaves;
        while (layer.length > 1) {
            bytes32[] memory newLayer = new bytes32[]((layer.length + 1) / 2);
            for (uint256 i = 0; i < layer.length; i += 2) {
                if (i + 1 == layer.length) {
                    newLayer[i / 2] = layer[i];
                } else {
                    newLayer[i / 2] = keccak256(abi.encodePacked(
                        layer[i] < layer[i + 1] ? layer[i] : layer[i + 1],
                        layer[i] < layer[i + 1] ? layer[i + 1] : layer[i]
                    ));
                }
            }
            layer = newLayer;
        }
        return layer[0];
    }
    
    // 辅助函数：使用 OpenZeppelin 的 MerkleProof 库生成 proof
    function _generateProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](leaves.length - 1);
        uint256 proofIndex = 0;
        
        for (uint256 i = 0; i < leaves.length; i++) {
            if (i != index) {
                proof[proofIndex] = leaves[i];
                proofIndex++;
            }
        }
        
        return proof;
    }
} 
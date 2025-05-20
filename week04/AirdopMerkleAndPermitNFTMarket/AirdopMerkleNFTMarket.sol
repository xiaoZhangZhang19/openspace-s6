// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./MarketToken.sol";
import "./MarketNFT.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract AirdopMerkleNFTMarket is ERC721Holder, Ownable {
    bytes32 public immutable merkleRoot;

    // 市场中上架的NFT结构
    struct Listing {
        address seller;
        uint256 price; // 以MarketToken为单位的价格
        address nftContract;
        address tokenContract;
    }
    
    // tokenId => Listing
    mapping(uint256 => Listing) private _listings;
    
    // 事件
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, address tokenContract, uint256 price);
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price);
    event NFTPurchasedByTokenReceived(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller);
    
    constructor(bytes32 merkleRoot_) Ownable(msg.sender) {
        merkleRoot = merkleRoot_;
    }

    //permitPrePay() : 调用token的 permit 进行授权
    function permitPrePay(
        address tokenContract,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(tokenContract).permit(msg.sender, spender, value, deadline, v, r, s);
    }

    /**
     * @dev 用户购买NFT
     */
    function buy(
        address nftContract,
        address tokenContract,
        uint256 tokenId
    ) external {

        Listing memory listing = _listings[tokenId];
        require(listing.nftContract == nftContract, "NFTMarket: wrong NFT contract");
        require(listing.tokenContract == tokenContract, "NFTMarket: wrong token contract");
        
        // 验证买家有足够的token
        MarketToken token = MarketToken(tokenContract);
        require(token.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.seller, listing.price);
        
        // 移除上架信息
        delete _listings[tokenId];
    }

    /**
     * @dev 用户购买NFT（白名单优惠50%）
     */
    function claimNFT(
        address nftContract,
        address tokenContract,
        uint256 tokenId,
        address account,
        bytes32[] calldata merkleProof
    ) external {
        bytes32 node = keccak256(abi.encodePacked(account));

        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );

        Listing memory listing = _listings[tokenId];
        require(listing.nftContract == nftContract, "NFTMarket: wrong NFT contract");
        require(listing.tokenContract == tokenContract, "NFTMarket: wrong token contract");
        
        // 验证买家有足够的token（优惠50%）
        MarketToken token = MarketToken(tokenContract);
        uint256 discountedPrice = listing.price / 2;
        require(token.balanceOf(msg.sender) >= discountedPrice, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, discountedPrice), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.seller, discountedPrice);
        
        // 移除上架信息
        delete _listings[tokenId];
    }

    /**
     * @dev 上架NFT到市场
     */
    function list(address nftContract, uint256 tokenId, address tokenContract, uint256 price) external {
        require(price > 0, "NFTMarket: price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner of NFT");
        
        // 将NFT转移到市场合约
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 记录上架信息
        _listings[tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenContract: tokenContract,
            price: price
        });
        
        emit NFTListed(nftContract, tokenId, msg.sender, tokenContract, price);
    }

    /**
     * @dev 批量调用函数
     * @param data 要调用的函数数据数组
     */
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
        return results;
    }
} 

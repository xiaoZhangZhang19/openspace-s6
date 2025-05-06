// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketToken.sol";
import "./MarketNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarket is ERC20TokenReceiver, ERC721Holder, ReentrancyGuard {
    // 市场中上架的NFT结构
    struct Listing {
        address seller;
        uint256 price; // 以MarketToken为单位的价格
        bool isActive;
    }
    
    // NFT合约地址
    address public nftContract;
    // 市场Token合约地址
    address public tokenContract;
    
    // tokenId => Listing
    mapping(uint256 => Listing) private _listings;
    
    // 事件
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);
    
    constructor(address _nftContract, address _tokenContract) {
        nftContract = _nftContract;
        tokenContract = _tokenContract;
    }
    
    /**
     * @dev 上架NFT到市场
     * @param tokenId 要上架的NFT ID
     * @param price 以MarketToken为单位的价格
     */
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "NFTMarket: price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner of NFT");
        
        // 将NFT转移到市场合约
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 记录上架信息
        _listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            isActive: true
        });
        
        emit NFTListed(tokenId, msg.sender, price);
    }
    
    /**
     * @dev 使用MarketToken购买NFT
     * @param tokenId 要购买的NFT ID
     */
    function buyNFT(uint256 tokenId) external nonReentrant {
        Listing memory listing = _listings[tokenId];
        require(listing.isActive, "NFTMarket: NFT not listed");
        
        // 验证买家有足够的token
        MarketToken token = MarketToken(tokenContract);
        MarketNFT nft = MarketNFT(nftContract);
        require(token.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 移除上架信息
        delete _listings[tokenId];
        
        emit NFTPurchased(tokenId, msg.sender, listing.seller, listing.price);
    }
    
    /**
     * @dev ERC20TokenReceiver接口实现，用于接收token并自动购买NFT
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        require(msg.sender == tokenContract, "NFTMarket: only market token allowed");
        require(to == address(this), "NFTMarket: receiver must be market");
        
        // 解析data参数获取要购买的tokenId
        require(data.length == 32, "NFTMarket: invalid data length");
        uint256 tokenId = abi.decode(data, (uint256));
        
        Listing memory listing = _listings[tokenId];
        require(listing.isActive, "NFTMarket: NFT not listed");
        require(amount >= listing.price, "NFTMarket: insufficient token amount");
        
        // 将token转给卖家
        MarketToken token = MarketToken(tokenContract);
        require(token.transfer(listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 如果用户发送了多余的token，将多余的部分退回
        if (amount > listing.price) {
            require(token.transfer(from, amount - listing.price), "NFTMarket: refund failed");
        }
        
        // 将NFT转给买家
        IERC721(nftContract).safeTransferFrom(address(this), from, tokenId);
        
        // 移除上架信息
        delete _listings[tokenId];
        
        emit NFTPurchased(tokenId, from, listing.seller, listing.price);
        
        return true;
    }
} 

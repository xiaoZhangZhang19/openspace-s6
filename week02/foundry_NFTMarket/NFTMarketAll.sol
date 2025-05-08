// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MarketToken.sol";
import "./MarketNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarketAll is ERC20TokenReceiver, ERC721Holder, ReentrancyGuard {
    // 市场中上架的NFT结构
    struct Listing {
        address seller;
        address tokenContract;
        uint256 price; // 以MarketToken为单位的价格
        bool isActive;
    }
    
    // nftContract => tokenId => Listing
    mapping(address => mapping (uint256 => Listing)) private _listings;
    
    // 事件
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price);
    
    /**
     * @dev 上架NFT到市场
     * @param nftContract 要上架的NFT合约地址
     * @param tokenId 要上架的NFT ID
     * @param tokenContract 要使用的MarketToken合约地址
     * @param price 以MarketToken为单位的价格
     */
    function list(address nftContract, uint256 tokenId, address tokenContract, uint256 price) external {
        require(price > 0, "NFTMarket: price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner of NFT");
        
        // 将NFT转移到市场合约，执行之前需要用户给NFTMarket授权
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 记录上架信息
        _listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            tokenContract: tokenContract,
            price: price,
            isActive: true
        });
        
        emit NFTListed(nftContract, tokenId, msg.sender, price);
    }
    
    /**
     * @dev 使用MarketToken购买NFT
     * @param nftContract 要购买的NFT合约地址
     * @param tokenContract 要使用的MarketToken合约地址
     * @param tokenId 要购买的NFT ID
     */
    function buyNFT(address nftContract, uint256 tokenId, address tokenContract) external nonReentrant {
        Listing memory listing = _listings[nftContract][tokenId];
        require(listing.isActive, "NFTMarket: NFT not listed");
        //验证买家不是卖家
        require(msg.sender != listing.seller, "NFTMarket: buyer is seller");
        // 验证买家有足够的token
        MarketToken token = MarketToken(tokenContract);
        MarketNFT nft = MarketNFT(nftContract);
        require(token.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 移除上架信息
        delete _listings[nftContract][tokenId];
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.seller, listing.price);
    }
    
    /**
     * @dev ERC20TokenReceiver接口实现，用于接收token并自动购买NFT
     * @param operator 操作员地址
     * @param from 发送者地址
     * @param to 接收者地址
     * @param amount 发送的token数量
     * @param data 数据
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        require(to == address(this), "NFTMarket: receiver must be market");
        
        // 解析data参数获取要购买的tokenId
        require(data.length == 96, "NFTMarket: invalid data length");
        (address nftContract, address tokenContract, uint256 tokenId) = abi.decode(data, (address, address, uint256));
        
        Listing memory listing = _listings[nftContract][tokenId];
        require(listing.isActive, "NFTMarket: NFT not listed");
        require(amount >= listing.price, "NFTMarket: insufficient token amount");
        
        // 将token转给卖家，执行的msg.sender是NFTMarketAll合约
        MarketToken token = MarketToken(tokenContract);
        require(token.transfer(listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 如果用户发送了多余的token，将多余的部分退回
        if (amount > listing.price) {
            require(token.transfer(from, amount - listing.price), "NFTMarket: refund failed");
        }
        
        // 将NFT转给买家
        IERC721(nftContract).safeTransferFrom(address(this), from, tokenId);
        
        // 移除上架信息
        delete _listings[nftContract][tokenId];
        
        emit NFTPurchased(nftContract, tokenId, from, listing.seller, listing.price);
        
        return true;
    }

    function getListing(address nftContract, uint256 tokenId) external view returns (Listing memory) {
        return _listings[nftContract][tokenId];
    }
} 

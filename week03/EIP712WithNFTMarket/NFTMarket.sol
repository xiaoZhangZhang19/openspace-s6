// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./MarketToken.sol";
import "./MarketNFT.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NFTMarket is ERC721Holder, ReentrancyGuard, Ownable, EIP712 {
    // 市场中上架的NFT结构
    struct Listing {
        address seller;
        address nftContract;
        address tokenContract;
        uint256 price; // 以MarketToken为单位的价格
        bool isActive;
    }
    
    // 白名单签名相关
    bytes32 public constant WHITELIST_TYPEHASH = keccak256(
        "WhitelistPermit(address buyer,uint256 nonce,uint256 deadline)"
    );
    
    // 用户nonce，防止重放攻击
    mapping(address => uint256) public nonces;
    
    // tokenId => Listing
    mapping(uint256 => Listing) private _listings;
    
    // 事件
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, address tokenContract, uint256 price);
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price);
    event NFTPurchasedByTokenReceived(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller);
    
    constructor() EIP712("NFTMarket", "1.0") {}

    /**
     * @dev 验证白名单签名
     */
    function _verifyWhitelistSignature(
        address buyer,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        require(block.timestamp <= deadline, "NFTMarket: signature expired");
        
        bytes32 structHash = keccak256(abi.encode(
            WHITELIST_TYPEHASH,
            buyer,
            nonces[buyer],
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0) && signer == owner(), "NFTMarket: invalid signature");
    }

    /**
     * @dev 白名单用户购买NFT
     */
    function permitBuy(
        address nftContract,
        address tokenContract,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // 验证白名单签名
        _verifyWhitelistSignature(msg.sender, deadline, v, r, s);
        
        Listing memory listing = _listings[tokenId];
        require(listing.isActive, "NFTMarket: NFT not listed");
        require(listing.nftContract == nftContract, "NFTMarket: wrong NFT contract");
        require(listing.tokenContract == tokenContract, "NFTMarket: wrong token contract");
        
        // 验证买家有足够的token
        MarketToken token = MarketToken(tokenContract);
        require(token.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        // 增加nonce
        nonces[msg.sender]++;
        
        // 移除上架信息
        delete _listings[tokenId];
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.seller, listing.price);
    }

    /**
     * @dev 上架NFT到市场
     * @param tokenId 要上架的NFT ID
     * @param price 以MarketToken为单位的价格
     */
    function list(address nftContract, uint256 tokenId, address tokenContract, uint256 price) external {
        require(price > 0, "NFTMarket: price must be greater than zero");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner of NFT");
        
        // 将NFT转移到市场合约，执行之前需要用户给NFTMarket授权
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 记录上架信息
        _listings[tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenContract: tokenContract,
            price: price,
            isActive: true
        });
        
        emit NFTListed(nftContract, tokenId, msg.sender, tokenContract, price);
    }
    
    /**
     * @dev 使用MarketToken购买NFT（仅供测试，生产环境应使用permitBuy）
     * @param tokenId 要购买的NFT ID
     */
    function buyNFT(address nftContract, address tokenContract, uint256 tokenId) payable external nonReentrant {
        revert("NFTMarket: use permitBuy instead");
    }

    // NFTMarket提现ETH
    function withdrawETH(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }

    // Allow the contract to receive ETH
    receive() external payable {}

    /**
     * @dev 返回域分隔符
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
} 

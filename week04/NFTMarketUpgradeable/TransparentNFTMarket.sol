// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./MarketToken.sol";
import "./MarketNFT.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract NFTMarket is Initializable, ERC721HolderUpgradeable, OwnableUpgradeable, EIP712Upgradeable {
    // 市场中上架的NFT结构
    struct Listing {
        address seller;
        uint256 price; // 以MarketToken为单位的价格
        address nftContract;
        address tokenContract;
    }
    
    // 白名单签名相关
    bytes32 public constant WHITELIST_TYPEHASH = keccak256(
        "WhitelistPermit(address buyer,uint256 nonce,uint256 deadline)"
    );
    
    // 用户nonce，防止重放攻击
    mapping(address => uint256) public nonces;
    
    // tokenId => Listing
    mapping(uint256 => Listing) public _listings;

    // 为将来的升级预留存储空间
    uint256[50] private __gap;
    
    // 事件
    event NFTListed(address indexed nftContract, uint256 indexed tokenId, address indexed seller, address tokenContract, uint256 price);
    event NFTPurchased(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller, uint256 price);
    event NFTPurchasedByTokenReceived(address indexed nftContract, uint256 indexed tokenId, address indexed buyer, address seller);
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     */
    function initialize(address initialOwner) public initializer {
        __ERC721Holder_init();
        __Ownable_init(initialOwner);
        __EIP712_init("NFTMarket", "1.0");
    }

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
        
        address signer = ecrecover(_hashTypedDataV4(structHash), v, r, s);
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
    ) external {
        // 验证白名单签名
        _verifyWhitelistSignature(msg.sender, deadline, v, r, s);
        
        Listing memory listing = _listings[tokenId];
        require(listing.nftContract == nftContract, "NFTMarket: wrong NFT contract");
        require(listing.tokenContract == tokenContract, "NFTMarket: wrong token contract");
        
        // 验证买家有足够的token
        MarketToken token = MarketToken(tokenContract);
        require(token.balanceOf(msg.sender) >= listing.price, "NFTMarket: insufficient token balance");
        
        // 转移token从买家到卖家
        require(token.transferFrom(msg.sender, listing.seller, listing.price), "NFTMarket: token transfer failed");
        
        // 转移NFT从市场到买家
        ERC721Upgradeable(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
        
        emit NFTPurchased(nftContract, tokenId, msg.sender, listing.seller, listing.price);

        // 增加nonce
        nonces[msg.sender]++;
        
        // 移除上架信息
        delete _listings[tokenId];
    }

    /**
     * @dev 上架NFT到市场
     * @param tokenId 要上架的NFT ID
     * @param price 以MarketToken为单位的价格
     */
    function list(address nftContract, uint256 tokenId, address tokenContract, uint256 price) external {
        require(price > 0, "NFTMarket: price must be greater than zero");
        require(ERC721Upgradeable(nftContract).ownerOf(tokenId) == msg.sender, "NFTMarket: not the owner of NFT");
        
        // 将NFT转移到市场合约，执行之前需要用户给NFTMarket授权
        ERC721Upgradeable(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        
        // 记录上架信息
        _listings[tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenContract: tokenContract,
            price: price
        });
        
        emit NFTListed(nftContract, tokenId, msg.sender, tokenContract, price);
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

    uint public upGradeTest;
    function addOldFunction() public {
        upGradeTest = upGradeTest + 1;
    }

    function getUpGradeTest() public view returns (uint) {
        return upGradeTest;
    }
} 

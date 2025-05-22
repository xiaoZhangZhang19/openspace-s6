// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./TransparentNFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketV2 is NFTMarket {
    function addNewFunction() public {
        upGradeTest = upGradeTest + 2;
    }
    
    // 离线签名上架NFT的结构体哈希
    bytes32 public constant LIST_WITH_SIGNATURE_TYPEHASH = keccak256(
        "ListWithSignature(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );
    
    // 通过离线签名上架NFT
    function listWithSignature(
        address nftContract,
        uint256 tokenId,
        address tokenContract,
        uint256 price,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(price > 0, "NFTMarketV2: price must be greater than zero");
        require(block.timestamp <= deadline, "NFTMarketV2: signature expired");
        
        // 获取NFT所有者
        address owner = IERC721(nftContract).ownerOf(tokenId);
        
        // 验证签名
        bytes32 structHash = keccak256(abi.encode(
            LIST_WITH_SIGNATURE_TYPEHASH,
            tokenId,
            price,
            nonces[owner],
            deadline
        ));
        
        address signer = ecrecover(_hashTypedDataV4(structHash), v, r, s);
        require(signer != address(0) && signer == owner, "NFTMarketV2: invalid signature");
        
        // 增加nonce，防止重放攻击
        nonces[owner]++;
        
        // 将NFT转移到市场合约
        IERC721(nftContract).safeTransferFrom(owner, address(this), tokenId);
        
        // 记录上架信息
        _listings[tokenId] = Listing({
            seller: owner,
            nftContract: nftContract,
            tokenContract: tokenContract,
            price: price
        });
        
        emit NFTListed(nftContract, tokenId, owner, tokenContract, price);
    }
} 

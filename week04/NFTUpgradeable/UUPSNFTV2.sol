// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./UUPSNFTV1.sol";

contract UUPSNFTV2 is UUPSNFTV1 {
    // 新的状态变量
    mapping(uint256 => uint256) private _tokenRarities;
    
    // V2功能的新事件
    event RaritySet(uint256 indexed tokenId, uint256 rarity);

    // 为代币设置稀有度的新函数
    function setRarity(uint256 tokenId, uint256 rarity) public onlyOwner {
        require(_tokenExists(tokenId), "Token does not exist");
        _tokenRarities[tokenId] = rarity;
        emit RaritySet(tokenId, rarity);
    }

    // 获取代币稀有度的新函数
    function getRarity(uint256 tokenId) public view returns (uint256) {
        require(_tokenExists(tokenId), "Token does not exist");
        return _tokenRarities[tokenId];
    }

    // 检查代币是否存在的辅助函数
    function _tokenExists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // V2新增批量铸造功能
    function batchMint(address to, string[] memory uris) public onlyOwner {
        for (uint i = 0; i < uris.length; i++) {
            safeMint(to, uris[i]);
        }
    }
} 
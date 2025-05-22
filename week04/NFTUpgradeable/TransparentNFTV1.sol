// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TransparentNFTV1 is 
    ERC721Upgradeable, 
    ERC721URIStorageUpgradeable, 
    OwnableUpgradeable 
{
    uint256 private _nextTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    //在逻辑合约部署时自动调用构造函数，禁用所有初始化器，确保逻辑合约本身不能被初始化，只能通过代理进行初始化。
    constructor() {
        _disableInitializers();
    }

    //初始化函数，在代理合约中调用，初始化逻辑合约
    //由于代理模式不会执行逻辑合约的构造函数，因此你必须使用一个专门的函数来初始化逻辑合约的状态变量。
    function initialize(address initialOwner) public virtual initializer {
        __ERC721_init("MyNFT", "MNFT");
        __ERC721URIStorage_init();
        __Ownable_init(initialOwner);
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    // 在ERC721和ERC721URIStorage都有这个函数，所以必须重写tokenURI函数
    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // 在ERC721和ERC721URIStorage都有这个函数，所以必须重写supportsInterface函数
    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, ERC721URIStorageUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
} 
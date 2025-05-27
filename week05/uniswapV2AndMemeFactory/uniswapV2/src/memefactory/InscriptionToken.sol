// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title 铭文代币合约
 * @dev 实现ERC20标准的铭文代币
 * @notice 该合约支持铸造和转账功能
 */
contract InscriptionToken is ERC20, Ownable {
    /// @notice 代币总供应量上限
    uint256 public totalSupplyLimit;
    /// @notice 每次铸造的代币数量
    uint256 public perMintAmount;
    /// @notice 铸造价格
    uint256 public mintPrice;
    /// @notice 代币创建者地址
    address public creator;
    /// @notice 已铸造的代币总量
    uint256 public totalMinted;
    /// @notice 合约是否已初始化
    bool private _initialized;
    /// @notice 工厂合约地址
    address public immutable factory;

    // 存储代币名称和符号
    string private _tokenName;
    string private _tokenSymbol;

    /**
     * @dev 构造函数，设置工厂合约地址
     */
    // 通过传入空字符串，可以避免在部署时需要指定名称和符号，同时方便后期设置具体的值
    constructor() ERC20("", "") Ownable(msg.sender) {
        factory = msg.sender;
    }

    /**
     * @notice 初始化代币合约
     * @param tokenSymbol 代币符号
     * @param _totalSupplyLimit 代币总供应量上限
     * @param _perMint 每次铸造数量
     * @param _price 铸造价格
     * @param _creator 创建者地址
     */
    function initialize(
        string memory tokenSymbol,
        uint256 _totalSupplyLimit,
        uint256 _perMint,
        uint256 _price,
        address _creator
    ) external {
        require(!_initialized, "Already initialized");
        require(msg.sender == factory, "Only factory can initialize");
        _initialized = true;

        _tokenName = string(abi.encodePacked("Inscription ", tokenSymbol));
        _tokenSymbol = tokenSymbol;
        totalSupplyLimit = _totalSupplyLimit;
        perMintAmount = _perMint;
        mintPrice = _price;
        creator = _creator;
        // 将合约所有权转移给创建者
        _transferOwnership(_creator);
    }

    /// @notice 获取代币名称
    // 通过重写name()修改代币name
    function name() public view override returns (string memory) {
        return _tokenName;
    }

    /// @notice 获取代币符号
    // 通过重写symbol()修改代币symbol
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     * @dev 内部代币铸造函数
     */
    function _mintTokens(address to) internal {
        require(totalMinted + perMintAmount <= totalSupplyLimit, "Exceeds total supply");
        
        totalMinted += perMintAmount;
        _mint(to, perMintAmount);
    }

    /**
     * @notice 直接铸造函数
     */
    // 加入payable，可以接收以太币
    function mintTo(address to) external payable {
        require(msg.sender == creator || msg.sender == factory, "Only creator or factory can mint");
        require(msg.value >= mintPrice, "Insufficient payment");
        _mintTokens(to);
    }

    /**
     * @notice 提取合约中的以太币
     */
    function withdraw() external {
        require(msg.sender == creator, "Only creator can withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = payable(creator).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
} 
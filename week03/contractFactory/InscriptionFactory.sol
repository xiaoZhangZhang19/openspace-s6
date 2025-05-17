// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./InscriptionToken.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title 铭文工厂合约
 * @dev 用于部署和管理铭文代币合约的工厂合约
 * @notice 该合约使用最小代理模式来部署新的铭文代币
 */
contract InscriptionFactory is Ownable {
    using Clones for address;

    /// @notice 铭文代币实现合约地址
    address public immutable tokenImplementation;
    /// @notice 铸造费用百分比（10%）
    uint256 public constant FEE_PERCENTAGE = 10;
    /// @notice 记录地址是否为工厂创建的铭文代币
    mapping(address => bool) public isInscriptionToken;
    mapping(string => address) public inscriptions;
    uint256 public fee;
    
    /**
     * @notice 铭文代币部署事件
     * @param symbol 代币符号
     * @param token 部署的代币合约地址
     */
    event InscriptionDeployed(string indexed symbol, address indexed token);

    /**
     * @notice 铭文代币铸造事件
     * @param symbol 代币符号
     * @param to 铸造者地址
     * @param amount 铸造数量
     */
    event InscriptionMinted(string indexed symbol, address indexed to, uint256 amount);

    /**
     * @dev 构造函数，部署实现合约并设置所有者
     */
    constructor() Ownable(msg.sender) {
        tokenImplementation = address(new InscriptionToken());
    }

    /**
     * @notice 设置铸造费用
     * @param _fee 新的铸造费用
     */
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice 部署新的铭文代币合约
     * @param symbol 代币符号
     * @param totalSupply 代币总供应量
     * @param perMint 每次铸造数量
     * @param price 铸造价格（单位：wei）
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external payable {
        require(msg.value >= fee, "Insufficient fee");
        require(inscriptions[symbol] == address(0), "Symbol already exists");
        require(totalSupply > 0, "Total supply must be positive");
        require(perMint > 0 && perMint <= totalSupply, "Invalid perMint amount");
        require(price > 0, "Price must be positive");

        // 使用代理模式克隆实现合约，只部署一个最小代理合约（约 45 字节）
        // 所有调用都委托给实现合约，大大节省 gas 成本
        address payable clone = payable(tokenImplementation.clone());
        // 初始化代理合约
        InscriptionToken(clone).initialize(symbol, totalSupply, perMint, price, msg.sender);
        
        isInscriptionToken[clone] = true;
        inscriptions[symbol] = clone;
        emit InscriptionDeployed(symbol, clone);

        // 如果有多余的 ETH，返还给发送者
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
    }

    /**
     * @notice 铸造铭文代币
     * @param symbol 代币符号
     */
    function mintInscription(string memory symbol) external payable {
        require(inscriptions[symbol] != address(0), "Token not created by this factory");
        
        address payable tokenAddr = payable(inscriptions[symbol]);
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 mintPrice = token.mintPrice();

        // 计算平台费用
        uint256 platformFee = (mintPrice * FEE_PERCENTAGE) / 100;
        uint256 totalRequired = mintPrice + platformFee;
        require(msg.value >= totalRequired, "Insufficient payment");

        // 铸造代币
        token.mintTo{value: mintPrice}(msg.sender);

        // 如果有多余的 ETH，返还给发送者
        uint256 excess = msg.value - totalRequired;
        if (excess > 0) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }

        emit InscriptionMinted(symbol, msg.sender, token.perMintAmount());
    }

    /**
     * @notice 工厂合约owner提取合约中的以太币
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    receive() external payable {}
} 
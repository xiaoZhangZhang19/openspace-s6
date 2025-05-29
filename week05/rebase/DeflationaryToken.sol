// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title 通缩代币
 * @dev 实现通缩机制的ERC20代币。
 * 每年总供应量减少1%。
 */
contract DeflationaryToken is ERC20, Ownable {
    using Math for uint256;

    // 弹性供应机制
    uint256 private _totalShares; // 内部份额记账
    uint256 private _totalSupply; // 重新基数后的实际总供应量
    mapping(address => uint256) private _shares; // 用户份额的内部记账
    
    // 重新基数追踪
    uint256 public lastRebaseTime;
    uint256 public constant REBASE_PERIOD = 365 days; // 年度重新基数周期
    uint256 public constant DEFLATION_RATE = 99; // 99%（1%通缩率）
    uint256 public constant DEFLATION_PRECISION = 100;

    // 初始供应量为1亿代币，含18位小数
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18;

    /**
     * @dev 构造函数，将初始供应量分配给消息发送者。
     */
    constructor() ERC20("Deflationary Token", "DFLT") Ownable(msg.sender) {
        // 使用标准ERC20的_mint铸造初始供应量
        super._mint(msg.sender, INITIAL_SUPPLY);
        
        // 为接收者初始化份额
        _shares[msg.sender] = INITIAL_SUPPLY;
        _totalShares = INITIAL_SUPPLY;
        
        // 设置总供应量
        _totalSupply = INITIAL_SUPPLY;
        
        // 设置初始重新基数时间
        lastRebaseTime = block.timestamp;
    }

    /**
     * @dev 当代币被铸造时更新份额的内部函数
     * 在_mint之后调用，用于更新份额记账
     */
    function _mintShares(address account, uint256 amount) internal {
        _shares[account] += amount;
        _totalShares += amount;
        _totalSupply = super.totalSupply();
    }

    /**
     * @dev 当代币被销毁时更新份额的内部函数
     * 在_burn之后调用，用于更新份额记账
     */
    function _burnShares(address account, uint256 amount) internal {
        // 计算实际要销毁的份额
        uint256 sharesToBurn = (amount * _totalShares) / _totalSupply;
        
        _shares[account] -= sharesToBurn;
        _totalShares -= sharesToBurn;
        _totalSupply = super.totalSupply();
    }

    /**
     * @dev 自定义铸造函数，同时更新份额
     */
    function mint(address account, uint256 amount) external onlyOwner {
        super._mint(account, amount);
        _mintShares(account, amount);
    }

    /**
     * @dev 自定义销毁函数，同时更新份额
     */
    function burn(address account, uint256 amount) external {
        require(account == msg.sender || owner() == msg.sender, "Only token owner or contract owner can burn");
        super._burn(account, amount);
        _burnShares(account, amount);
    }

    /**
     * @dev 重写transfer函数以适应重新基数机制
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        address owner = _msgSender();
        
        // 将金额转换为份额
        uint256 sharesToTransfer = amount * _totalShares / _totalSupply;
        
        // 更新份额
        _shares[owner] -= sharesToTransfer;
        _shares[to] += sharesToTransfer;
        
        // 执行实际的ERC20转账
        return super.transfer(to, amount);
    }

    /**
     * @dev 重写transferFrom函数以适应重新基数机制
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        // 将金额转换为份额
        uint256 sharesToTransfer = amount * _totalShares / _totalSupply;
        
        // 更新份额
        _shares[from] -= sharesToTransfer;
        _shares[to] += sharesToTransfer;
        
        // 执行实际的ERC20转账
        return super.transferFrom(from, to, amount);
    }

    /**
     * @dev 重写balanceOf函数，返回弹性调整后的余额
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_totalShares == 0) return 0;
        
        return (_shares[account] * _totalSupply) / _totalShares;
    }

    /**
     * @dev 获取账户的份额余额
     */
    function sharesOf(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev 获取总份额
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev 重写totalSupply，返回重新基数后的当前供应量
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev 执行重新基数操作，每年减少总供应量1%
     * 任何人都可以触发，但只有当距上次重新基数已过一年时才能操作
     */
    function rebase() external {
        // 检查是否已经过了足够的时间进行重新基数
        uint256 timeSinceLastRebase = block.timestamp - lastRebaseTime;
        require(timeSinceLastRebase >= REBASE_PERIOD, "Rebase period not elapsed");

        // 计算新的总供应量（当前供应量的99%）
        uint256 newTotalSupply = (_totalSupply * DEFLATION_RATE) / DEFLATION_PRECISION;
        
        // 更新总供应量，但不改变份额
        uint256 supplyDelta = _totalSupply - newTotalSupply;
        _totalSupply = newTotalSupply;
        
        // 从所有者那里销毁代币（必要的，保持ERC20余额和我们的记账同步）
        super._burn(owner(), supplyDelta);
        
        // 更新上次重新基数时间
        lastRebaseTime = block.timestamp;
        
        emit Rebase(_totalSupply, _totalShares);
    }

    /**
     * @dev 设置上次重新基数时间（仅用于测试目的）
     * 此函数允许在测试中绕过时间限制
     */
    function setLastRebaseTimeForTesting(uint256 timestamp) external onlyOwner {
        lastRebaseTime = timestamp;
    }

    /**
     * @dev 重新基数事件
     */
    event Rebase(uint256 totalSupply, uint256 totalShares);
} 
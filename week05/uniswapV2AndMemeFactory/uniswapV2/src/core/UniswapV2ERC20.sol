// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import '../interfaces/IUniswapV2ERC20.sol';
import '../libraries/SafeMath.sol';

/**
 * @title UniswapV2ERC20
 * @dev 实现ERC20代币标准的合约，用于表示Uniswap V2交易对的流动性代币
 * 包含了EIP-2612的permit功能，允许通过签名进行授权
 */
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint;

    // 代币名称
    string public constant name = 'Uniswap V2';
    // 代币符号
    string public constant symbol = 'UNI-V2';
    // 代币小数位数
    uint8 public constant decimals = 18;
    // 代币总供应量
    uint public totalSupply;
    // 用户余额映射
    mapping(address => uint) public balanceOf;
    // 授权映射
    mapping(address => mapping(address => uint)) public allowance;

    // EIP-712域分隔符，用于防止跨链重放攻击
    bytes32 public DOMAIN_SEPARATOR;
    // EIP-2612 permit函数的类型哈希
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // 用户nonce映射，防止重放攻击
    mapping(address => uint) public nonces;

    // 事件在接口中已定义，这里不再重复定义

    /**
     * @dev 构造函数，初始化EIP-712域分隔符
     */
    constructor() {
        uint chainId;
        // 获取当前链ID
        assembly {
            chainId := chainid()
        }
        
        // 计算域分隔符
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @dev 内部铸造函数，创建新代币并分配给指定地址
     * @param to 接收代币的地址
     * @param value 铸造的代币数量
     */
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    /**
     * @dev 内部销毁函数，从指定地址销毁代币
     * @param from 销毁代币的地址
     * @param value 销毁的代币数量
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    /**
     * @dev 内部授权函数，设置授权额度
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权额度
     */
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev 内部转账函数，从一个地址转移代币到另一个地址
     * @param from 发送者地址
     * @param to 接收者地址
     * @param value 转账金额
     */
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev 授权函数，允许spender花费调用者的代币
     * @param spender 被授权者地址
     * @param value 授权金额
     * @return 是否成功
     */
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev 转账函数，将调用者的代币转移到指定地址
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev 授权转账函数，将一个地址的代币转移到另一个地址（需要授权）
     * @param from 发送者地址
     * @param to 接收者地址
     * @param value 转账金额
     * @return 是否成功
     */
    function transferFrom(address from, address to, uint value) external returns (bool) {
        // 如果授权额度不是最大值，则减少授权额度
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev 通过签名授权函数，允许通过签名进行授权而不需要发送交易
     * @param owner 代币所有者
     * @param spender 被授权者
     * @param value 授权金额
     * @param deadline 签名有效期
     * @param v 签名的v值
     * @param r 签名的r值
     * @param s 签名的s值
     */
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external virtual override {
        // 确保签名未过期
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        
        // 计算消息摘要
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        
        // 恢复签名者地址
        address recoveredAddress = ecrecover(digest, v, r, s);
        
        // 验证签名者是否为所有者
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        
        // 设置授权
        _approve(owner, spender, value);
    }
} 
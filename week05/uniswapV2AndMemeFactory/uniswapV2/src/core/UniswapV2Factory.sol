// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import '../interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

/**
 * @title UniswapV2Factory
 * @dev 工厂合约负责创建和管理交易对
 * 它是Uniswap V2的核心组件，用于创建新的交易对合约
 */
contract UniswapV2Factory is IUniswapV2Factory {
    // 协议费用接收地址，如果为零地址则不收取协议费
    address public feeTo;
    // 有权修改feeTo地址的账户
    address public feeToSetter;

    // 双重映射，用于存储token0和token1对应的交易对地址
    // 可以通过token0和token1查询对应的交易对地址
    mapping(address => mapping(address => address)) public getPair;
    // 存储所有已创建的交易对地址
    address[] public allPairs;

    // 事件在接口中已定义，这里不再重复定义

    /**
     * @dev 构造函数，设置有权修改协议费接收地址的账户
     * @param _feeToSetter 费用设置者地址
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @dev 返回已创建的交易对总数
     * @return 交易对数量
     */
    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    /**
     * @dev 创建新的交易对
     * @param tokenA 第一个代币地址
     * @param tokenB 第二个代币地址
     * @return pair 新创建的交易对地址
     */
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        // 确保两个代币地址不相同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        
        // 按地址大小排序代币，确保相同的代币对总是以相同的顺序存储
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        // 确保token0不是零地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        
        // 确保该交易对不存在
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        
        // 获取UniswapV2Pair合约的创建字节码
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        
        // 计算salt值，用于CREATE2操作
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        
        // 使用CREATE2创建新合约，确保地址可确定性
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        
        // 初始化交易对合约
        IUniswapV2Pair(pair).initialize(token0, token1);
        
        // 双向存储交易对映射关系
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        
        // 添加到所有交易对数组
        allPairs.push(pair);
        
        // 触发交易对创建事件
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 设置协议费接收地址
     * @param _feeTo 新的协议费接收地址
     */
    function setFeeTo(address _feeTo) external override {
        // 只有feeToSetter可以调用此函数
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
     * @dev 设置有权修改协议费接收地址的账户
     * @param _feeToSetter 新的feeToSetter地址
     */
    function setFeeToSetter(address _feeToSetter) external override {
        // 只有当前feeToSetter可以调用此函数
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
} 
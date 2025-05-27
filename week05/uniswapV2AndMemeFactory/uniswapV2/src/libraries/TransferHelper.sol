// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

/**
 * @title TransferHelper
 * @dev 提供安全的代币和ETH转账函数
 * 处理非标准ERC20实现和转账失败的情况
 */
library TransferHelper {
    /**
     * @dev 安全地转移代币
     * @param token 代币地址
     * @param to 接收地址
     * @param value 转账金额
     */
    function safeTransfer(address token, address to, uint value) internal {
        // 使用低级call调用transfer函数，而不是接口调用
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        
        // 检查调用是否成功，以及返回值（如果有）是否为true
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper: TRANSFER_FAILED'
        );
    }

    /**
     * @dev 安全地从指定地址转移代币
     * @param token 代币地址
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额
     */
    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // 使用低级call调用transferFrom函数
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        
        // 检查调用是否成功，以及返回值（如果有）是否为true
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper: TRANSFER_FROM_FAILED'
        );
    }

    /**
     * @dev 安全地给指定地址授权代币
     * @param token 代币地址
     * @param spender 被授权地址
     * @param value 授权金额
     */
    function safeApprove(address token, address spender, uint value) internal {
        // 使用低级call调用approve函数
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, spender, value)
        );
        
        // 检查调用是否成功，以及返回值（如果有）是否为true
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper: APPROVE_FAILED'
        );
    }

    /**
     * @dev 安全地转移ETH
     * @param to 接收地址
     * @param value 转账金额
     */
    function safeTransferETH(address to, uint value) internal {
        // 使用低级call发送ETH
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
} 
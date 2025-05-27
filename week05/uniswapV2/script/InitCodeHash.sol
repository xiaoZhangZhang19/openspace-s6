// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "../src/core/UniswapV2Pair.sol";

contract InitCodeHashScript is Script {
    function run() public {
        // 计算UniswapV2Pair合约的initcode hash
        bytes32 hash = keccak256(abi.encodePacked(type(UniswapV2Pair).creationCode));
        
        // 输出结果
        console.logBytes32(hash);
    }
} 
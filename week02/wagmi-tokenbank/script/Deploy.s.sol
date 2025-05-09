// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import "../src/MyTokenWithCallback.sol";
import "../src/TokenBank2.sol";

contract DeployScript is Script {
    function run() external {
        // Anvil's first account private key
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Token
        MyTokenWithCallback token = new MyTokenWithCallback(
            "Test Token",
            "TEST",
            1000000 ether
        );

        // Deploy TokenBank2
        TokenBank2 bank2 = new TokenBank2(address(token));

        console.log("Token deployed to:", address(token));
        console.log("TokenBank2 deployed to:", address(bank2));

        vm.stopBroadcast();
    }
} 
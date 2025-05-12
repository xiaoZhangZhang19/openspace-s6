// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    address[] public owners;
    uint256 public requiredConfirmations = 2;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public recipient = address(0x4);

    function setUp() public {
        // 设置测试账户
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        
        // 初始化多签持有者
        owners = new address[](3);
        owners[0] = alice;
        owners[1] = bob;
        owners[2] = charlie;
        
        // 部署合约
        wallet = new MultiSigWallet(owners, requiredConfirmations);
        
        // 给多签钱包转入一些 ETH
        vm.deal(address(wallet), 5 ether);
    }

    function test_Initialization() public {
        // 测试初始化
        assertEq(wallet.requiredConfirmations(), requiredConfirmations);
        assertEq(wallet.getOwners().length, 3);
        assertTrue(wallet.isOwner(alice));
        assertTrue(wallet.isOwner(bob));
        assertTrue(wallet.isOwner(charlie));
    }

    function test_SubmitProposal() public {
        // 测试提交提案
        vm.prank(alice);
        uint256 proposalId = wallet.submitProposal(recipient, 1 ether, "");
        assertEq(proposalId, 0);
        
        (address to, uint256 value, bytes memory data, bool executed, uint256 confirmations) = wallet.getProposal(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(executed, false);
        assertEq(confirmations, 0);
    }

    function test_ConfirmProposal() public {
        // 提交提案
        vm.prank(alice);
        uint256 proposalId = wallet.submitProposal(recipient, 1 ether, "");
        
        // 确认提案
        vm.prank(bob);
        wallet.confirmProposal(proposalId);
        
        (,,, bool executed, uint256 confirmations) = wallet.getProposal(proposalId);
        assertEq(confirmations, 1);
        assertEq(executed, false);
    }

    function test_ExecuteProposal() public {
        // 提交提案
        vm.prank(alice);
        uint256 proposalId = wallet.submitProposal(recipient, 1 ether, "");
        
        // 确认提案
        vm.prank(bob);
        wallet.confirmProposal(proposalId);
        vm.prank(charlie);
        wallet.confirmProposal(proposalId);
        
        // 执行提案
        vm.prank(alice);
        wallet.executeProposal(proposalId);
        
        // 验证执行结果
        (,,, bool executed, uint256 confirmations) = wallet.getProposal(proposalId);
        assertEq(executed, true);
        assertEq(confirmations, 2);
        assertEq(recipient.balance, 1 ether);
    }

    function test_RevertWhen_ExecuteWithoutEnoughConfirmations() public {
        // 提交提案
        vm.prank(alice);
        uint256 proposalId = wallet.submitProposal(recipient, 1 ether, "");
        
        // 只确认一次
        vm.prank(bob);
        wallet.confirmProposal(proposalId);
        
        // 尝试执行（应该失败）
        vm.prank(alice);
        vm.expectRevert("Not enough confirmations");
        wallet.executeProposal(proposalId);
    }

    function test_RevertWhen_NonOwnerSubmitProposal() public {
        // 非多签持有者尝试提交提案
        vm.prank(recipient);
        vm.expectRevert("Not an owner");
        wallet.submitProposal(recipient, 1 ether, "");
    }

    function test_RevertWhen_DoubleConfirm() public {
        // 提交提案
        vm.prank(alice);
        uint256 proposalId = wallet.submitProposal(recipient, 1 ether, "");
        
        // 尝试重复确认
        vm.startPrank(bob);
        wallet.confirmProposal(proposalId);
        vm.expectRevert("Already confirmed");
        wallet.confirmProposal(proposalId);
        vm.stopPrank();
    }
} 
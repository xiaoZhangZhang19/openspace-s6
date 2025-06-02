// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/dao/GovernanceToken.sol";
import "../../src/dao/TimelockController.sol";
import "../../src/dao/Governor.sol";
import "../../src/dao/GovernedBank.sol";

contract DAOTest is Test {
    // 合约实例
    GovernanceToken public governanceToken;
    BankTimelockController public timelock;
    BankGovernor public governor;
    GovernedBank public bank;
    
    // 测试账户
    address public deployer;
    address public user1;
    address public user2;
    address public user3;
    address public recipient;
    
    // 测试参数
    uint256 public constant MIN_DELAY = 3600; // 1小时时间锁
    uint256 public constant VOTING_DELAY = 1; // 1个区块延迟
    uint256 public constant VOTING_PERIOD = 50; // 50个区块投票期
    
    // 用于跟踪提案ID
    uint256 public proposalId;

    function setUp() public {
        // 设置测试账户
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        recipient = makeAddr("recipient");

        // 部署合约
        vm.startPrank(deployer);
        
        // 部署治理代币
        governanceToken = new GovernanceToken();
        
        // 为测试用户分配代币
        governanceToken.transfer(user1, 100_000 * 10**18);
        governanceToken.transfer(user2, 200_000 * 10**18);
        governanceToken.transfer(user3, 300_000 * 10**18);
        
        // 部署Bank合约
        bank = new GovernedBank();
        
        // 部署时间锁控制器
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // 允许任何人执行
        
        timelock = new BankTimelockController(
            MIN_DELAY,
            proposers,
            executors
        );
        
        // 部署治理合约
        governor = new BankGovernor(
            governanceToken,
            timelock,
            bank
        );
        
        // 设置时间锁的角色
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = keccak256("TIMELOCK_ADMIN_ROLE"); // 直接使用字符串哈希替代常量
        
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); // 允许任何人执行
        timelock.revokeRole(adminRole, deployer); // 移除部署者的管理员角色
        
        // 将Bank的所有权转移给时间锁控制器
        bank.setDAOAsOwner(address(timelock));
        
        vm.stopPrank();
        
        // 向Bank合约存入资金
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        (bool success,) = address(bank).call{value: 5 ether}("");
        require(success, "Deposit failed");
        
        // 用户委托投票权
        vm.prank(user1);
        governanceToken.delegate(user1);
        
        vm.prank(user2);
        governanceToken.delegate(user2);
        
        vm.prank(user3);
        governanceToken.delegate(user3);
        
        // 向前推进几个区块，确保投票权生效
        vm.roll(block.number + 2);
    }

    function test_CreateProposal() public {
        vm.prank(user1);
        proposalId = governor.proposeWithdrawal(
            recipient,
            2 ether,
            "Proposal #1: Send 2 ETH to recipient"
        );
        
        // 验证提案是否创建成功
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending), "Proposal should be in Pending state");
        
        // 验证提案详情
        (BankGovernor.ProposalType proposalType, address proposalRecipient, uint256 amount, string memory description) = governor.getProposalInfo(proposalId);
        
        assertEq(uint256(proposalType), uint256(BankGovernor.ProposalType.WithdrawFunds), "Incorrect proposal type");
        assertEq(proposalRecipient, recipient, "Incorrect recipient");
        assertEq(amount, 2 ether, "Incorrect amount");
        assertEq(description, "Proposal #1: Send 2 ETH to recipient", "Incorrect description");
    }

    function test_VotingWorkflow() public {
        // 创建提案
        vm.prank(user1);
        proposalId = governor.proposeWithdrawal(
            recipient,
            2 ether,
            "Proposal #1: Send 2 ETH to recipient"
        );
        
        // 向前推进区块，使提案进入投票阶段
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 验证提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active), "Proposal should be in Active state");
        
        // 用户投票
        vm.prank(user1);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        vm.prank(user2);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        // 向前推进区块，结束投票期
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded), "Proposal should be in Succeeded state");
    }
} 
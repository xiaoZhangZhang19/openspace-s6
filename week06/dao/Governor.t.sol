// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {BankGovernor} from "../../src/dao/Governor.sol";
import {GovernedBank} from "../../src/dao/GovernedBank.sol";
import {GovernanceToken} from "../../src/dao/GovernanceToken.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernorTest is Test {
    // 合约实例
    BankGovernor public governor;
    GovernedBank public bank;
    GovernanceToken public token;
    TimelockController public timelock;
    
    // 测试账户
    address public deployer;
    address public proposer;
    address public voter1;
    address public voter2;
    address public voter3;
    address public recipient;
    
    // 常量
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18; // 初始代币供应量
    uint256 public constant PROPOSAL_THRESHOLD = 100_000 * 10**18; // 提案阈值
    uint256 public constant VOTING_DELAY = 7200; // 投票延迟（区块数）
    uint256 public constant VOTING_PERIOD = 50400; // 投票期（区块数）
    uint256 public constant MIN_DELAY = 2 days; // 最小延迟时间
    
    // 提案相关变量
    uint256 public proposalId;
    string public description = "withdraw funds";
    uint256 public withdrawAmount = 1 ether;
    
    function setUp() public {
        // 设置测试账户
        deployer = makeAddr("deployer");
        proposer = makeAddr("proposer");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        voter3 = makeAddr("voter3");
        recipient = makeAddr("recipient");
        
        // 给deployer账户添加ETH
        vm.deal(deployer, 20 ether);
        
        // 部署合约
        vm.startPrank(deployer);
        
        // 部署治理代币
        token = new GovernanceToken();
        
        // 设置时间锁控制器
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = deployer;
        executors[0] = address(0); // 任何人都可以执行
        
        timelock = new TimelockController(
            MIN_DELAY,
            proposers,
            executors,
            deployer
        );
        
        // 部署银行合约
        bank = new GovernedBank();
        
        // 部署治理合约
        governor = new BankGovernor(
            token,
            timelock,
            bank
        );
        
        // 将银行合约的所有权转移给时间锁控制器
        bank.setDAOAsOwner(address(timelock));
        
        // 向银行合约存入资金
        (bool success,) = address(bank).call{value: 10 ether}("");
        require(success, "Deposit failed");
        
        // 分配代币给提案者和投票者
        token.transfer(proposer, 200_000 * 10**18); // 给提案者足够的代币
        token.transfer(voter1, 150_000 * 10**18);
        token.transfer(voter2, 100_000 * 10**18);
        token.transfer(voter3, 50_000 * 10**18);
        
        // 授予时间锁控制器角色给治理合约
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // 允许任何人执行
        //在部署初始阶段，部署者拥有DEFAULT_ADMIN_ROLE，这赋予了他管理所有其他角色的权限
        //一旦治理系统设置完成，这个权限应该被移除，防止部署者保留后门
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer); // 撤销部署者的管理员角色
        
        vm.stopPrank();
        
        // 代表们委托投票权给自己
        vm.prank(proposer);
        token.delegate(proposer);
        
        vm.prank(voter1);
        token.delegate(voter1);
        
        vm.prank(voter2);
        token.delegate(voter2);
        
        vm.prank(voter3);
        token.delegate(voter3);
        
        // 推进区块，使委托生效
        vm.roll(block.number + 1);
    }
    
    function test_ProposalCreation() public {
        // 测试提案创建
        vm.prank(proposer);
        proposalId = governor.proposeWithdrawal(
            recipient,
            withdrawAmount,
            description
        );
        
        // 验证提案ID不为0
        assertTrue(proposalId != 0, "Proposal ID should not be 0");
        
        // 验证提案状态为Pending
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Pending), "Proposal should be in Pending state");
        
        // 验证提案信息
        (BankGovernor.ProposalType proposalType, address proposalRecipient, uint256 proposalAmount, string memory proposalDescription) = governor.getProposalInfo(proposalId);
        
        assertEq(uint(proposalType), uint(BankGovernor.ProposalType.WithdrawFunds), "Proposal type incorrect");
        assertEq(proposalRecipient, recipient, "Proposal recipient incorrect");
        assertEq(proposalAmount, withdrawAmount, "Proposal amount incorrect");
        assertEq(proposalDescription, description, "Proposal description incorrect");
    }
    
    function test_Voting() public {
        // 创建提案
        vm.prank(proposer);
        proposalId = governor.proposeWithdrawal(
            recipient,
            withdrawAmount,
            description
        );
        
        // 推进区块到投票开始
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 验证提案状态为Active
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Active), "Proposal should be in Active state");
        
        // 投票
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        vm.prank(voter2);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        vm.prank(voter3);
        governor.castVote(proposalId, 0); // 0 = 反对
        
        // 推进区块到投票结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案状态为Succeeded
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Succeeded), "Proposal should be in Succeeded state");
    }
    
    function test_QueueAndExecute() public {
        // 创建提案
        vm.prank(proposer);
        proposalId = governor.proposeWithdrawal(
            recipient,
            withdrawAmount,
            description
        );
        
        // 推进区块到投票开始
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 投票
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        vm.prank(voter2);
        governor.castVote(proposalId, 1); // 1 = 赞成
        
        // 推进区块到投票结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 队列提案
        governor.queueWithdrawal(proposalId);
        
        // 验证提案状态为Queued
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Queued), "Proposal should be in Queued state");
        
        // 推进时间到执行时间
        vm.warp(block.timestamp + MIN_DELAY + 1);
        
        // 记录初始余额
        uint256 initialBankBalance = address(bank).balance;
        uint256 initialRecipientBalance = recipient.balance;
        
        // 执行提案
        vm.prank(proposer);
        governor.executeWithdrawal(proposalId);
        
        // 验证资金已从银行转移到接收者
        assertEq(address(bank).balance, initialBankBalance - withdrawAmount, "Bank balance incorrect");
        assertEq(recipient.balance, initialRecipientBalance + withdrawAmount, "Recipient balance incorrect");
    }
    
    function test_PauseAndUnpause() public {
        // 测试暂停功能
        
        // 首先创建一个提案来暂停治理合约
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        string memory pauseDescription = "stop governance contract";
        
        targets[0] = address(governor);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(BankGovernor.pause.selector);
        
        vm.prank(proposer);
        uint256 pauseProposalId = governor.propose(targets, values, calldatas, pauseDescription);
        
        // 推进区块到投票开始
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 投票
        vm.prank(voter1);
        governor.castVote(pauseProposalId, 1); // 1 = 赞成
        
        vm.prank(voter2);
        governor.castVote(pauseProposalId, 1); // 1 = 赞成
        
        // 推进区块到投票结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 队列提案
        bytes32 pauseDescHash = keccak256(bytes(pauseDescription));
        vm.prank(proposer);
        governor.queue(targets, values, calldatas, pauseDescHash);
        
        // 推进时间到执行时间
        vm.warp(block.timestamp + MIN_DELAY + 1);
        
        // 执行提案
        vm.prank(proposer);
        governor.execute(targets, values, calldatas, pauseDescHash);
        
        // 验证合约已暂停
        assertTrue(governor.paused(), "Governor should be paused");
        
        // 尝试创建新提案，应该失败
        vm.prank(proposer);
        vm.expectRevert("Governor: paused");
        governor.proposeWithdrawal(recipient, withdrawAmount, "This should fail");
        
        // 创建一个提案来恢复治理合约
        calldatas[0] = abi.encodeWithSelector(BankGovernor.unpause.selector);
        string memory unpauseDescription = "recover governance contract";
        
        // 注意：由于合约已暂停，我们需要直接调用propose而不是proposeWithdrawal
        vm.prank(proposer);
        uint256 unpauseProposalId = governor.propose(targets, values, calldatas, unpauseDescription);
        
        // 推进区块到投票开始 - 使用正确的起始区块号
        vm.roll(64805); // voteStart + 1
        
        // 投票
        vm.prank(voter1);
        governor.castVote(unpauseProposalId, 1); // 1 = 赞成
        
        vm.prank(voter2);
        governor.castVote(unpauseProposalId, 1); // 1 = 赞成
        
        // 推进区块到投票结束
        vm.roll(115205); // voteEnd + 1
        
        // 队列提案
        bytes32 unpauseDescHash = keccak256(bytes(unpauseDescription));
        vm.prank(proposer);
        governor.queue(targets, values, calldatas, unpauseDescHash);
        
        // 推进时间到执行时间
        vm.warp(block.timestamp + MIN_DELAY * 2);
        
        // 执行提案
        vm.prank(proposer);
        governor.execute(targets, values, calldatas, unpauseDescHash);
        
        // 验证合约已恢复
        assertFalse(governor.paused(), "Governor should be unpaused");
        
        // 现在应该可以创建新提案
        vm.prank(proposer);
        uint256 newProposalId = governor.proposeWithdrawal(recipient, withdrawAmount, "This should succeed");
        assertTrue(newProposalId != 0, "Should be able to create proposal after unpause");
    }
    
    function test_FailedProposal() public {
        // 创建提案
        vm.prank(proposer);
        proposalId = governor.proposeWithdrawal(
            recipient,
            withdrawAmount,
            description
        );
        
        // 推进区块到投票开始
        vm.roll(block.number + VOTING_DELAY + 1);
        
        // 投票 - 这次让提案失败
        vm.prank(voter1);
        governor.castVote(proposalId, 0); // 0 = 反对
        
        vm.prank(voter2);
        governor.castVote(proposalId, 0); // 0 = 反对
        
        vm.prank(voter3);
        governor.castVote(proposalId, 0); // 0 = 反对
        
        // 推进区块到投票结束
        vm.roll(block.number + VOTING_PERIOD + 1);
        
        // 验证提案状态为Defeated
        assertEq(uint(governor.state(proposalId)), uint(IGovernor.ProposalState.Defeated), "Proposal should be in Defeated state");
        
        // 尝试队列失败的提案，应该失败
        bytes32 descHash = keccak256(bytes(description));
        vm.prank(proposer);
        vm.expectRevert();
        governor.queue(
            _singletonArray(address(bank)),
            _singletonArray(uint256(0)),
            _singletonArray(abi.encodeWithSelector(bank.withdraw.selector, withdrawAmount)),
            descHash
        );
    }
    
    function test_InsufficientVotes() public {
        // 创建一个没有足够投票权的账户
        address poorVoter = makeAddr("poorVoter");
        vm.prank(deployer);
        token.transfer(poorVoter, 50_000 * 10**18); // 低于提案阈值
        
        vm.prank(poorVoter);
        token.delegate(poorVoter);
        
        // 推进区块，使委托生效
        vm.roll(block.number + 1);
        
        // 尝试创建提案，应该失败
        vm.prank(poorVoter);
        vm.expectRevert();
        governor.proposeWithdrawal(
            recipient,
            withdrawAmount,
            "This should fail due to insufficient votes"
        );
    }

    // 辅助函数：创建只包含一个元素的数组
    function _singletonArray(address element) private pure returns (address[] memory) {
        address[] memory array = new address[](1);
        array[0] = element;
        return array;
    }

    function _singletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

    function _singletonArray(bytes memory element) private pure returns (bytes[] memory) {
        bytes[] memory array = new bytes[](1);
        array[0] = element;
        return array;
    }
    
    receive() external payable {}
}
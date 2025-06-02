// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "../Bank/Bank.sol";

/**
 * @title BankGovernor
 * @dev 实现治理合约，使用GovernanceToken代币进行投票，管理Bank合约
 */
contract BankGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // 指向管理的Bank合约
    Bank public bankContract;
    
    // 提案状态枚举
    enum ProposalType {
        WithdrawFunds
    }
    
    // 提案信息结构
    struct ProposalInfo {
        ProposalType proposalType;
        address recipient;
        uint256 amount;
        string description;
    }
    
    // 存储提案ID到提案信息的映射
    mapping(uint256 => ProposalInfo) public proposalInfos;

    constructor(
        IVotes _token,
        TimelockController _timelock,
        Bank _bank
    )
        Governor("BankGovernor")
        GovernorSettings(
            1, /* 1 block voting delay */
            50, /* 50 blocks voting period */
            0 /* 0 threshold */
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(4) // 4% quorum
        GovernorTimelockControl(_timelock)
    {
        bankContract = _bank;
    }

    /**
     * @dev 创建一个从Bank提取资金的提案
     * @param recipient 资金接收者地址
     * @param amount 提取金额
     * @param description 提案描述
     */
    function proposeWithdrawal(
        address recipient,
        uint256 amount,
        string memory description
    ) public returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than 0");

        // 调用合约函数的编码
        bytes memory callData = abi.encodeWithSelector(
            Bank.withdraw.selector,
            amount  // 添加金额参数
        );

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bankContract);
        values[0] = 0; // 不发送ETH
        calldatas[0] = callData;

        // 创建提案
        uint256 proposalId = super.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 存储提案详情
        proposalInfos[proposalId] = ProposalInfo({
            proposalType: ProposalType.WithdrawFunds,
            recipient: recipient,
            amount: amount,
            description: description
        });

        return proposalId;
    }

    /**
     * @dev 在提案执行后，将资金发送到指定的接收者地址
     * @param proposalId 提案ID
     */
    function executeWithdrawal(uint256 proposalId) public payable {
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");
        
        ProposalInfo storage info = proposalInfos[proposalId];
        require(info.proposalType == ProposalType.WithdrawFunds, "Not a withdrawal proposal");
        
        // 使用proposalHash来执行提案
        bytes32 descriptionHash = keccak256(bytes(info.description));
        
        // 重新构建提案参数
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        
        targets[0] = address(bankContract);
        values[0] = 0; // 不发送ETH
        calldatas[0] = abi.encodeWithSelector(Bank.withdraw.selector);
        
        // 执行提案，这将调用Bank.withdraw()，资金会转入时间锁
        execute(targets, values, calldatas, descriptionHash);
        
        // 创建时间锁提案，将资金从时间锁发送到最终接收者
        address[] memory timelocktargets = new address[](1);
        uint256[] memory timelockvalues = new uint256[](1);
        bytes[] memory timelockcalldatas = new bytes[](1);
        
        timelocktargets[0] = info.recipient;
        timelockvalues[0] = info.amount; // 发送指定金额的ETH
        timelockcalldatas[0] = "";
        
        // 使用时间锁的API，发送资金给接收者
        string memory timelockDescription = string(abi.encodePacked("Forward funds to recipient: ", info.description));
        bytes32 timelockDescHash = keccak256(bytes(timelockDescription));
        
        TimelockController timelock = TimelockController(payable(timelock()));
        timelock.schedule(
            timelocktargets[0],
            timelockvalues[0],
            timelockcalldatas[0],
            bytes32(0),
            timelockDescHash,
            timelock.getMinDelay()
        );
        
        // 立即执行转账操作
        timelock.execute(
            timelocktargets[0],
            timelockvalues[0],
            timelockcalldatas[0],
            bytes32(0),
            timelockDescHash
        );
    }

    /**
     * @dev 获取提案详情
     * @param proposalId 提案ID
     */
    function getProposalInfo(uint256 proposalId) public view returns (
        ProposalType,
        address,
        uint256,
        string memory
    ) {
        ProposalInfo memory info = proposalInfos[proposalId];
        return (info.proposalType, info.recipient, info.amount, info.description);
    }

    // 接收ETH，用于接收Bank合约发送的资金
    receive() external payable override {}

    // 以下函数是必须重写的函数，用于解决多重继承问题
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(Governor) returns (uint256) {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
} 
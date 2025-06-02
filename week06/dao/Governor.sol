// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.29;  // 指定Solidity编译器版本为0.8.29或更高

import "@openzeppelin/contracts/governance/Governor.sol";  // 导入OpenZeppelin的Governor合约
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";  // 导入GovernorSettings扩展
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";  // 导入GovernorCountingSimple扩展
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";  // 导入GovernorVotes扩展
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";  // 导入GovernorVotesQuorumFraction扩展
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";  // 导入GovernorTimelockControl扩展
import "./GovernedBank.sol";  // 导入GovernedBank合约

/**
 * @title BankGovernor  // 合约标题
 * @dev 实现治理合约，使用GovernanceToken代币进行投票，管理Bank合约  // 合约描述
 */
contract BankGovernor is  // 定义BankGovernor合约
    Governor,  // 继承Governor基础合约
    GovernorSettings,  // 继承GovernorSettings扩展
    GovernorCountingSimple,  // 继承GovernorCountingSimple扩展
    GovernorVotes,  // 继承GovernorVotes扩展
    GovernorVotesQuorumFraction,  // 继承GovernorVotesQuorumFraction扩展
    GovernorTimelockControl  // 继承GovernorTimelockControl扩展
{
    // 指向管理的Bank合约
    GovernedBank public bankContract;  // 声明公共变量，存储Bank合约引用
    
    // 提案状态枚举
    enum ProposalType {  // 定义提案类型枚举
        WithdrawFunds  // 提取资金类型
    }
    
    // 提案信息结构
    struct ProposalInfo {  // 定义提案信息结构体
        ProposalType proposalType;  // 提案类型
        address recipient;  // 资金接收者地址
        uint256 amount;  // 提取金额
        string description;  // 提案描述
    }
    
    // 存储提案ID到提案信息的映射
    mapping(uint256 => ProposalInfo) public proposalInfos;  // 声明公共映射，存储提案信息

    constructor(  // 构造函数
        IVotes _token,  // 投票代币接口参数
        TimelockController _timelock,  // 时间锁控制器参数
        GovernedBank _bank  // Bank合约参数
    )
        Governor("BankGovernor")  // 初始化Governor，设置名称
        GovernorSettings(  // 初始化GovernorSettings
            1, /* 1 block voting delay */  // 投票延迟1个区块
            50, /* 50 blocks voting period */  // 投票期50个区块
            0 /* 0 threshold */  // 提案阈值为0
        )
        GovernorVotes(_token)  // 初始化GovernorVotes，传入投票代币
        GovernorVotesQuorumFraction(4) // 4% quorum  // 初始化法定人数为4%
        GovernorTimelockControl(_timelock)  // 初始化时间锁控制
    {
        bankContract = _bank;  // 设置Bank合约引用
    }

    /**
     * @dev 创建一个从Bank提取资金的提案  // 函数描述
     * @param recipient 资金接收者地址  // 参数描述
     * @param amount 提取金额  // 参数描述
     * @param description 提案描述  // 参数描述
     */
    function proposeWithdrawal(  // 定义提案创建函数
        address recipient,  // 接收者地址参数
        uint256 amount,  // 金额参数
        string memory description  // 描述参数
    ) public returns (uint256) {  // 返回提案ID
        require(recipient != address(0), "Invalid recipient");  // 验证接收者地址不为零地址
        require(amount > 0, "Amount must be greater than 0");  // 验证金额大于0

        // 调用合约函数的编码
        bytes memory callData = abi.encodeWithSelector(  // 编码函数调用数据
            Bank.withdraw.selector,  // 使用Bank合约的withdraw函数选择器
            amount  // 添加金额参数
        );

        address[] memory targets = new address[](1);  // 创建目标地址数组
        uint256[] memory values = new uint256[](1);  // 创建值数组
        bytes[] memory calldatas = new bytes[](1);  // 创建调用数据数组
        
        targets[0] = address(bankContract);  // 设置目标为Bank合约地址
        values[0] = 0; // 不发送ETH  // 设置值为0
        calldatas[0] = callData;  // 设置调用数据

        // 创建提案
        uint256 proposalId = super.propose(  // 调用父合约的propose函数
            targets,  // 传入目标数组
            values,  // 传入值数组
            calldatas,  // 传入调用数据数组
            description  // 传入描述
        );

        // 存储提案详情
        proposalInfos[proposalId] = ProposalInfo({  // 创建并存储提案信息
            proposalType: ProposalType.WithdrawFunds,  // 设置类型为提取资金
            recipient: recipient,  // 设置接收者
            amount: amount,  // 设置金额
            description: description  // 设置描述
        });

        return proposalId;  // 返回提案ID
    }

    /**
     * @dev 在提案执行后，将资金发送到指定的接收者地址  // 函数描述
     * @param proposalId 提案ID  // 参数描述
     */
    function executeWithdrawal(uint256 proposalId) public payable {  // 定义执行提案函数
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");  // 验证提案状态为已排队
        
        ProposalInfo storage info = proposalInfos[proposalId];  // 获取提案信息
        require(info.proposalType == ProposalType.WithdrawFunds, "Not a withdrawal proposal");  // 验证提案类型
        
        // 使用proposalHash来执行提案
        bytes32 descriptionHash = keccak256(bytes(info.description));  // 计算描述的哈希值
        
        // 重新构建提案参数
        address[] memory targets = new address[](1);  // 创建目标地址数组
        uint256[] memory values = new uint256[](1);  // 创建值数组
        bytes[] memory calldatas = new bytes[](1);  // 创建调用数据数组
        
        targets[0] = address(bankContract);  // 设置目标为Bank合约地址
        values[0] = 0; // 不发送ETH  // 设置值为0
        calldatas[0] = abi.encodeWithSelector(Bank.withdraw.selector);  // 编码withdraw函数调用
        
        // 执行提案，这将调用Bank.withdraw()，资金会转入时间锁
        execute(targets, values, calldatas, descriptionHash);  // 执行提案
        
        // 创建时间锁提案，将资金从时间锁发送到最终接收者
        address[] memory timelocktargets = new address[](1);  // 创建时间锁目标数组
        uint256[] memory timelockvalues = new uint256[](1);  // 创建时间锁值数组
        bytes[] memory timelockcalldatas = new bytes[](1);  // 创建时间锁调用数据数组
        
        timelocktargets[0] = info.recipient;  // 设置目标为接收者地址
        timelockvalues[0] = info.amount; // 发送指定金额的ETH  // 设置值为提案金额
        timelockcalldatas[0] = "";  // 设置空调用数据
        
        // 使用时间锁的API，发送资金给接收者
        string memory timelockDescription = string(abi.encodePacked("Forward funds to recipient: ", info.description));  // 创建时间锁描述
        bytes32 timelockDescHash = keccak256(bytes(timelockDescription));  // 计算描述哈希
        
        TimelockController timelock = TimelockController(payable(timelock()));  // 获取时间锁控制器
        timelock.schedule(  // 调用时间锁的schedule函数
            timelocktargets[0],  // 传入目标
            timelockvalues[0],  // 传入值
            timelockcalldatas[0],  // 传入调用数据
            bytes32(0),  // 传入空的predecessor
            timelockDescHash,  // 传入描述哈希
            timelock.getMinDelay()  // 传入最小延迟
        );
        
        // 立即执行转账操作
        timelock.execute(  // 调用时间锁的execute函数
            timelocktargets[0],  // 传入目标
            timelockvalues[0],  // 传入值
            timelockcalldatas[0],  // 传入调用数据
            bytes32(0),  // 传入空的predecessor
            timelockDescHash  // 传入描述哈希
        );
    }

    /**
     * @dev 获取提案详情  // 函数描述
     * @param proposalId 提案ID  // 参数描述
     */
    function getProposalInfo(uint256 proposalId) public view returns (  // 定义查看提案信息函数
        ProposalType,  // 返回提案类型
        address,  // 返回接收者地址
        uint256,  // 返回金额
        string memory  // 返回描述
    ) {
        ProposalInfo memory info = proposalInfos[proposalId];  // 获取提案信息
        return (info.proposalType, info.recipient, info.amount, info.description);  // 返回提案详情
    }

    // 接收ETH，用于接收Bank合约发送的资金
    receive() external payable override {}  // 重写receive函数，接收ETH

    // 以下函数是必须重写的函数，用于解决多重继承问题
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {  // 重写votingDelay函数
        return super.votingDelay();  // 调用父合约的votingDelay函数
    }

    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {  // 重写votingPeriod函数
        return super.votingPeriod();  // 调用父合约的votingPeriod函数
    }

    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {  // 重写quorum函数
        return super.quorum(blockNumber);  // 调用父合约的quorum函数
    }

    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {  // 重写state函数
        return super.state(proposalId);  // 调用父合约的state函数
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {  // 重写proposalThreshold函数
        return super.proposalThreshold();  // 调用父合约的proposalThreshold函数
    }

    function propose(  // 重写propose函数
        address[] memory targets,  // 目标地址数组参数
        uint256[] memory values,  // 值数组参数
        bytes[] memory calldatas,  // 调用数据数组参数
        string memory description  // 描述参数
    ) public override(Governor) returns (uint256) {  // 返回提案ID
        return super.propose(targets, values, calldatas, description);  // 调用父合约的propose函数
    }

    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {  // 重写proposalNeedsQueuing函数
        return super.proposalNeedsQueuing(proposalId);  // 调用父合约的proposalNeedsQueuing函数
    }

    function _queueOperations(  // 重写_queueOperations内部函数
        uint256 proposalId,  // 提案ID参数
        address[] memory targets,  // 目标地址数组参数
        uint256[] memory values,  // 值数组参数
        bytes[] memory calldatas,  // 调用数据数组参数
        bytes32 descriptionHash  // 描述哈希参数
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {  // 返回时间戳
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);  // 调用父合约的_queueOperations函数
    }

    function _executeOperations(  // 重写_executeOperations内部函数
        uint256 proposalId,  // 提案ID参数
        address[] memory targets,  // 目标地址数组参数
        uint256[] memory values,  // 值数组参数
        bytes[] memory calldatas,  // 调用数据数组参数
        bytes32 descriptionHash  // 描述哈希参数
    ) internal override(Governor, GovernorTimelockControl) {  // 无返回值
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);  // 调用父合约的_executeOperations函数
    }

    function _cancel(  // 重写_cancel内部函数
        address[] memory targets,  // 目标地址数组参数
        uint256[] memory values,  // 值数组参数
        bytes[] memory calldatas,  // 调用数据数组参数
        bytes32 descriptionHash  // 描述哈希参数
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {  // 返回提案ID
        return super._cancel(targets, values, calldatas, descriptionHash);  // 调用父合约的_cancel函数
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {  // 重写_executor内部函数
        return super._executor();  // 调用父合约的_executor函数
    }

    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {  // 重写supportsInterface函数
        return super.supportsInterface(interfaceId);  // 调用父合约的supportsInterface函数
    }
}  // 合约结束
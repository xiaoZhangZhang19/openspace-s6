// SPDX-License-Identifier: MIT 
// 指定Solidity编译器版本为0.8.29或更高
pragma solidity ^0.8.29;

// 导入OpenZeppelin的Governor合约
import "@openzeppelin/contracts/governance/Governor.sol";
// 导入GovernorSettings扩展
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
// 导入GovernorCountingSimple扩展
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
// 导入GovernorVotes扩展
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
// 导入GovernorVotesQuorumFraction扩展
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
// 导入GovernorTimelockControl扩展
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
// 导入GovernedBank合约
import "./GovernedBank.sol";


/**
 * 总结
 * 通过propose创建提案，通过queue将提案排队，通过execute执行提案
 * 创建提案后需要等待时间就可以进行投票，投票时间过了，判断是否通过
 * 通过后，需要通过queue将提案排队，排队后需要等待时间锁延迟过期
 * 时间锁延迟过期后，通过execute执行提案
 */
/**
 * @title BankGovernor
 * @dev 实现治理合约，使用GovernanceToken代币进行投票，管理Bank合约
 */
// 定义BankGovernor合约
contract BankGovernor is
    // 继承Governor基础合约
    Governor,
    // 继承GovernorSettings扩展
    GovernorSettings,
    // 继承GovernorCountingSimple扩展
    GovernorCountingSimple,
    // 继承GovernorVotes扩展
    GovernorVotes,
    // 继承GovernorVotesQuorumFraction扩展
    GovernorVotesQuorumFraction,
    // 继承GovernorTimelockControl扩展
    GovernorTimelockControl
{
    // 指向管理的Bank合约
    // 声明公共变量，存储Bank合约引用
    GovernedBank public bankContract;
    
    // 提案状态枚举
    // 定义提案类型枚举
    enum ProposalType {
        // 提取资金类型
        WithdrawFunds
    }
    
    // 提案信息结构
    // 定义提案信息结构体
    struct ProposalInfo {
        // 提案类型
        ProposalType proposalType;
        // 资金接收者地址
        address recipient;
        // 提取金额
        uint256 amount;
        // 提案描述
        string description;
        // 提案是否已执行
        bool executed;
    }
    
    // 存储提案ID到提案信息的映射
    // 声明公共映射，存储提案信息
    mapping(uint256 => ProposalInfo) public proposalInfos;

    // 事件：提案执行
    event ProposalExecuted(uint256 indexed proposalId, uint256 amount, address recipient);
    
    // 公共变量：是否暂停
    bool public paused;
    
    // 修饰器：当合约未暂停时
    modifier whenNotPaused() {
        require(!paused, "Governor: paused");
        _;
    }

    // 构造函数
    constructor(
        // 投票代币接口参数
        IVotes _token,
        // 时间锁控制器参数
        TimelockController _timelock,
        // Bank合约参数
        GovernedBank _bank
    )
        // 初始化Governor，设置名称
        Governor("BankGovernor")
        // 初始化GovernorSettings
        GovernorSettings(
            // 投票延迟1天（假设12秒一个区块）
            7200, /* 1 day voting delay (assuming 12s block time) */
            // 投票期1周
            50400, /* 1 week voting period */
            // 提案阈值为10万个代币
            100000 * 10**18 /* 100,000 tokens threshold */
        )
        // 初始化GovernorVotes，传入投票代币
        GovernorVotes(_token)
        // 至少需要4%的总投票权参与投票才能使提案有效。
        GovernorVotesQuorumFraction(4) // 4% quorum  
        // 初始化时间锁控制
        GovernorTimelockControl(_timelock)
    {
        // 设置Bank合约引用
        bankContract = _bank;
    }

    /**
     * @dev 创建一个从Bank提取资金的提案
     * @param recipient 资金接收者地址
     * @param amount 提取金额
     * @param description 提案描述
     */
    // 定义提案创建函数
    function proposeWithdrawal(
        // 接收者地址参数
        address recipient,
        // 金额参数
        uint256 amount,
        // 描述参数
        string memory description
    ) public whenNotPaused returns (uint256) {
        // 验证接收者地址不为零地址
        require(recipient != address(0), "Invalid recipient");
        // 验证金额大于0
        require(amount > 0, "Amount must be greater than 0");
        // 验证Bank合约余额足够
        require(amount <= address(bankContract).balance, "Insufficient bank balance");

        // 创建提案
        // 调用父合约的propose函数
        uint256 proposalId = super.propose(
            // 传入目标数组
            _singletonArray(address(bankContract)),
            // 传入值数组
            _singletonArray(uint256(0)),
            // 传入调用数据数组，是targets中的函数选择器
            _singletonArray(abi.encodeWithSelector(GovernedBank.withdrawTo.selector, recipient, amount)),
            // 传入描述
            description
        );

        // 存储提案详情
        // 创建并存储提案信息
        proposalInfos[proposalId] = ProposalInfo({
            // 设置类型为提取资金
            proposalType: ProposalType.WithdrawFunds,
            // 设置接收者
            recipient: recipient,
            // 设置金额
            amount: amount,
            // 设置描述
            description: description,
            // 设置未执行
            executed: false
        });

        // 返回提案ID
        return proposalId;
    }

    /**
     * @dev 将已通过投票的提案排队等待执行
     * @param proposalId 提案ID
     */
    function queueWithdrawal(uint256 proposalId) public whenNotPaused returns (uint256) {
        // 验证提案状态为成功
        require(state(proposalId) == ProposalState.Succeeded, "Proposal not succeeded");
        
        // 获取提案信息
        ProposalInfo storage info = proposalInfos[proposalId];
        // 验证提案类型
        require(info.proposalType == ProposalType.WithdrawFunds, "Not a withdrawal proposal");
        
        // 计算描述的哈希值
        bytes32 descriptionHash = keccak256(bytes(info.description));
        
        // 准备调用数据，使用withdrawTo函数
        bytes memory callData = abi.encodeWithSelector(
            GovernedBank.withdrawTo.selector,
            info.recipient,
            info.amount
        );
        
        // 调用queue函数将提案排队
        return super.queue(
            _singletonArray(address(bankContract)),
            _singletonArray(uint256(0)),
            _singletonArray(callData),
            descriptionHash
        );
    }

    /**
     * @dev 执行提案，将资金从Bank直接发送到接收者
     * @param proposalId 提案ID
     */
    function executeWithdrawal(uint256 proposalId) public payable whenNotPaused {
        // 验证提案状态为已排队
        require(state(proposalId) == ProposalState.Queued, "Proposal not queued");
        
        // 获取提案信息
        ProposalInfo storage info = proposalInfos[proposalId];
        // 验证提案类型
        require(info.proposalType == ProposalType.WithdrawFunds, "Not a withdrawal proposal");
        // 验证提案未执行
        require(!info.executed, "Proposal already executed");
        // 验证Bank合约余额足够
        require(address(bankContract).balance >= info.amount, "Insufficient bank balance");
        
        // 计算描述的哈希值
        bytes32 descriptionHash = keccak256(bytes(info.description));
        
        // 标记提案为已执行
        info.executed = true;
        
        // 准备调用数据，使用withdrawTo函数
        bytes memory callData = abi.encodeWithSelector(
            GovernedBank.withdrawTo.selector,
            info.recipient,
            info.amount
        );
        
        // 执行提案
        super.execute(
            _singletonArray(address(bankContract)),
            _singletonArray(uint256(0)),
            _singletonArray(callData),
            descriptionHash
        );
        
        // 触发事件
        emit ProposalExecuted(proposalId, info.amount, info.recipient);
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

    /**
     * @dev 获取提案详情
     * @param proposalId 提案ID
     */
    // 定义查看提案信息函数
    function getProposalInfo(uint256 proposalId) public view returns (
        // 返回提案类型
        ProposalType,
        // 返回接收者地址
        address,
        // 返回金额
        uint256,
        // 返回描述
        string memory
    ) {
        // 获取提案信息
        ProposalInfo memory info = proposalInfos[proposalId];
        // 返回提案详情
        return (info.proposalType, info.recipient, info.amount, info.description);
    }

    // 接收ETH，用于接收Bank合约发送的资金
    // 重写receive函数，接收ETH
    receive() external payable override {}

    // 以下函数是必须重写的函数，用于解决多重继承问题
    // 重写votingDelay函数
    function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
        // 调用父合约的votingDelay函数
        return super.votingDelay();
    }

    // 重写votingPeriod函数
    function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
        // 调用父合约的votingPeriod函数
        return super.votingPeriod();
    }

    // 重写quorum函数
    function quorum(uint256 blockNumber) public view override(Governor, GovernorVotesQuorumFraction) returns (uint256) {
        // 调用父合约的quorum函数
        return super.quorum(blockNumber);
    }

    // 重写state函数
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        // 调用父合约的state函数
        return super.state(proposalId);
    }

    // 重写proposalThreshold函数
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        // 调用父合约的proposalThreshold函数
        return super.proposalThreshold();
    }

    // 重写propose函数
    function propose(
        // 目标地址数组参数
        address[] memory targets,
        // 值数组参数
        uint256[] memory values,
        // 调用数据数组参数
        bytes[] memory calldatas,
        // 描述参数
        string memory description
    ) public override(Governor) returns (uint256) {
        // 调用父合约的propose函数
        return super.propose(targets, values, calldatas, description);
    }

    // 重写proposalNeedsQueuing函数
    function proposalNeedsQueuing(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (bool) {
        // 调用父合约的proposalNeedsQueuing函数
        return super.proposalNeedsQueuing(proposalId);
    }

    // 重写_queueOperations内部函数
    function _queueOperations(
        // 提案ID参数
        uint256 proposalId,
        // 目标地址数组参数
        address[] memory targets,
        // 值数组参数
        uint256[] memory values,
        // 调用数据数组参数
        bytes[] memory calldatas,
        // 描述哈希参数
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        // 调用父合约的_queueOperations函数
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    // 重写_executeOperations内部函数
    function _executeOperations(
        // 提案ID参数
        uint256 proposalId,
        // 目标地址数组参数
        address[] memory targets,
        // 值数组参数
        uint256[] memory values,
        // 调用数据数组参数
        bytes[] memory calldatas,
        // 描述哈希参数
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        // 调用父合约的_executeOperations函数
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    // 重写_cancel内部函数
    function _cancel(
        // 目标地址数组参数
        address[] memory targets,
        // 值数组参数
        uint256[] memory values,
        // 调用数据数组参数
        bytes[] memory calldatas,
        // 描述哈希参数
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        // 调用父合约的_cancel函数
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    // 重写_executor内部函数
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        // 调用父合约的_executor函数
        return super._executor();
    }

    // 重写supportsInterface函数
    function supportsInterface(bytes4 interfaceId) public view override(Governor) returns (bool) {
        // 调用父合约的supportsInterface函数
        return super.supportsInterface(interfaceId);
    }

    // 管理函数：暂停合约
    function pause() public onlyGovernance {
        paused = true;
    }

    // 管理函数：恢复合约
    function unpause() public onlyGovernance {
        paused = false;
    }
}
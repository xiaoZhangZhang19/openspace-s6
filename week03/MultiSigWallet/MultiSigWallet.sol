// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MultiSigWallet {
    // 提案结构
    struct Proposal {
        address to;           // 目标地址
        uint256 value;        // 转账金额
        bytes data;           // 调用数据
        bool executed;        // 是否已执行
        uint256 confirmations; // 确认数量
    }

    // 事件
    event ProposalSubmitted(uint256 indexed proposalId, address indexed proposer, address to, uint256 value, bytes data);
    event ProposalConfirmed(uint256 indexed proposalId, address indexed confirmer);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);

    // 状态变量
    address[] public owners;                  // 多签持有者列表
    mapping(address => bool) public isOwner;  // 是否为多签持有者
    uint256 public requiredConfirmations;     // 所需确认数量
    Proposal[] public proposals;              // 提案列表
    mapping(uint256 => mapping(address => bool)) public hasConfirmed; // 记录每个提案的确认状态

    // 修饰器
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposalId < proposals.length, "Proposal does not exist");
        _;
    }

    modifier notExecuted(uint256 proposalId) {
        require(!proposals[proposalId].executed, "Proposal already executed");
        _;
    }

    modifier notConfirmed(uint256 proposalId) {
        require(!hasConfirmed[proposalId][msg.sender], "Already confirmed");
        _;
    }

    // 构造函数
    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _owners.length, "Invalid number of required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
            emit OwnerAdded(owner);
        }

        requiredConfirmations = _requiredConfirmations;
    }

    // 提交提案
    function submitProposal(address _to, uint256 _value, bytes memory _data) public onlyOwner returns (uint256) {
        uint256 proposalId = proposals.length;
        proposals.push(Proposal({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));
        emit ProposalSubmitted(proposalId, msg.sender, _to, _value, _data);
        return proposalId;
    }

    // 确认提案
    function confirmProposal(uint256 proposalId) 
        public 
        onlyOwner 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
        notConfirmed(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        proposal.confirmations += 1;
        hasConfirmed[proposalId][msg.sender] = true;
        emit ProposalConfirmed(proposalId, msg.sender);
    }

    // 执行提案
    function executeProposal(uint256 proposalId) 
        public 
        proposalExists(proposalId) 
        notExecuted(proposalId) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.confirmations >= requiredConfirmations, "Not enough confirmations");

        proposal.executed = true;
        (bool success, ) = proposal.to.call{value: proposal.value}(proposal.data);
        require(success, "Transaction failed");
        emit ProposalExecuted(proposalId, msg.sender);
    }

    // 获取提案数量
    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }

    // 获取提案详情
    function getProposal(uint256 proposalId) public view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 confirmations
    ) {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.to,
            proposal.value,
            proposal.data,
            proposal.executed,
            proposal.confirmations
        );
    }

    // 获取所有多签持有者
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    // 接收 ETH
    receive() external payable {}
} 
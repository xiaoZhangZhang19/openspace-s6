// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;  // 指定Solidity编译器版本为0.8.29或更高

import {Test, console2} from "forge-std/Test.sol";  // 导入Forge标准测试库
import "../../src/dao/GovernanceToken.sol";  // 导入GovernanceToken合约
import "@openzeppelin/contracts/governance/TimelockController.sol";  // 导入TimelockController合约
import "../../src/dao/Governor.sol";  // 导入Governor合约
import "../../src/dao/GovernedBank.sol";  // 导入GovernedBank合约

contract DAOTest is Test {  // 定义DAOTest合约，继承Test
    // 合约实例
    GovernanceToken public governanceToken;  // 声明治理代币实例
    TimelockController public timelock;  // 声明时间锁控制器实例
    BankGovernor public governor;  // 声明治理合约实例
    GovernedBank public bank;  // 声明银行合约实例
    
    // 测试账户
    address public deployer;  // 声明部署者地址
    address public user1;  // 声明用户1地址
    address public user2;  // 声明用户2地址
    address public user3;  // 声明用户3地址
    address public recipient;  // 声明接收者地址
    
    // 测试参数
    uint256 public constant MIN_DELAY = 3600; // 1小时时间锁  // 定义最小延迟常量
    uint256 public constant VOTING_DELAY = 1; // 1个区块延迟  // 定义投票延迟常量
    uint256 public constant VOTING_PERIOD = 50; // 50个区块投票期  // 定义投票期常量
    
    // 用于跟踪提案ID
    uint256 public proposalId;  // 声明提案ID变量

    function setUp() public {  // 定义测试设置函数
        // 设置测试账户
        deployer = makeAddr("deployer");  // 创建部署者地址
        user1 = makeAddr("user1");  // 创建用户1地址
        user2 = makeAddr("user2");  // 创建用户2地址
        user3 = makeAddr("user3");  // 创建用户3地址
        recipient = makeAddr("recipient");  // 创建接收者地址

        // 部署合约
        vm.startPrank(deployer);  // 开始模拟部署者操作
        
        // 部署治理代币
        governanceToken = new GovernanceToken();  // 部署治理代币合约
        
        // 为测试用户分配代币
        governanceToken.transfer(user1, 100_000 * 10**18);  // 向用户1转账代币
        governanceToken.transfer(user2, 200_000 * 10**18);  // 向用户2转账代币
        governanceToken.transfer(user3, 300_000 * 10**18);  // 向用户3转账代币
        
        // 部署Bank合约
        bank = new GovernedBank();  // 部署银行合约
        
        // 部署时间锁控制器
        address[] memory proposers = new address[](1);  // 创建提案者数组
        address[] memory executors = new address[](1);  // 创建执行者数组
        executors[0] = address(0); // 允许任何人执行  // 设置零地址为执行者，表示任何人都可以执行
        
        timelock = new TimelockController(  // 部署时间锁控制器
            MIN_DELAY,  // 传入最小延迟
            proposers,  // 传入提案者数组
            executors,  // 传入执行者数组
            deployer  // 传入管理员地址
        );
        
        // 部署治理合约
        governor = new BankGovernor(  // 部署治理合约
            governanceToken,  // 传入治理代币
            timelock,  // 传入时间锁控制器
            bank  // 传入银行合约
        );
        
        // 设置时间锁的角色
        bytes32 proposerRole = timelock.PROPOSER_ROLE();  // 获取提案者角色
        bytes32 executorRole = timelock.EXECUTOR_ROLE();  // 获取执行者角色
        bytes32 adminRole = keccak256("TIMELOCK_ADMIN_ROLE"); // 直接使用字符串哈希替代常量  // 计算管理员角色
        
        timelock.grantRole(proposerRole, address(governor));  // 授予治理合约提案者角色
        timelock.grantRole(executorRole, address(0)); // 允许任何人执行  // 授予零地址执行者角色
        timelock.revokeRole(adminRole, deployer); // 移除部署者的管理员角色  // 撤销部署者的管理员角色
        
        // 将Bank的所有权转移给时间锁控制器
        bank.setDAOAsOwner(address(timelock));  // 设置时间锁为银行合约的所有者
        
        vm.stopPrank();  // 结束模拟部署者操作
        
        // 向Bank合约存入资金
        vm.deal(user1, 10 ether);  // 给用户1分配10个ETH
        vm.prank(user1);  // 模拟用户1操作
        (bool success,) = address(bank).call{value: 5 ether}("");  // 向银行合约发送5个ETH
        require(success, "Deposit failed");  // 确保存款成功
        
        // 用户委托投票权
        vm.prank(user1);  // 模拟用户1操作
        governanceToken.delegate(user1);  // 用户1将投票权委托给自己
        
        vm.prank(user2);  // 模拟用户2操作
        governanceToken.delegate(user2);  // 用户2将投票权委托给自己
        
        vm.prank(user3);  // 模拟用户3操作
        governanceToken.delegate(user3);  // 用户3将投票权委托给自己
        
        // 向前推进几个区块，确保投票权生效
        vm.roll(block.number + 2);  // 推进区块高度
    }

    function test_CreateProposal() public {  // 定义创建提案测试函数
        vm.prank(user1);  // 模拟用户1操作
        proposalId = governor.proposeWithdrawal(  // 调用提案创建函数
            recipient,  // 传入接收者地址
            2 ether,  // 传入2个ETH
            "Proposal #1: Send 2 ETH to recipient"  // 传入提案描述
        );
        
        // 验证提案是否创建成功
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending), "Proposal should be in Pending state");  // 断言提案状态为待处理
        
        // 验证提案详情
        (BankGovernor.ProposalType proposalType, address proposalRecipient, uint256 amount, string memory description) = governor.getProposalInfo(proposalId);  // 获取提案信息
        
        assertEq(uint256(proposalType), uint256(BankGovernor.ProposalType.WithdrawFunds), "Incorrect proposal type");  // 断言提案类型正确
        assertEq(proposalRecipient, recipient, "Incorrect recipient");  // 断言接收者地址正确
        assertEq(amount, 2 ether, "Incorrect amount");  // 断言金额正确
        assertEq(description, "Proposal #1: Send 2 ETH to recipient", "Incorrect description");  // 断言描述正确
    }

    function test_VotingWorkflow() public {  // 定义投票流程测试函数
        // 创建提案
        vm.prank(user1);  // 模拟用户1操作
        proposalId = governor.proposeWithdrawal(  // 调用提案创建函数
            recipient,  // 传入接收者地址
            2 ether,  // 传入2个ETH
            "Proposal #1: Send 2 ETH to recipient"  // 传入提案描述
        );
        
        // 向前推进区块，使提案进入投票阶段
        vm.roll(block.number + VOTING_DELAY + 1);  // 推进区块高度
        
        // 验证提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active), "Proposal should be in Active state");  // 断言提案状态为活跃
        
        // 用户投票
        vm.prank(user1);  // 模拟用户1操作
        governor.castVote(proposalId, 1); // 1 = 赞成  // 用户1投赞成票
        
        vm.prank(user2);  // 模拟用户2操作
        governor.castVote(proposalId, 1); // 1 = 赞成  // 用户2投赞成票
        
        // 向前推进区块，结束投票期
        vm.roll(block.number + VOTING_PERIOD + 1);  // 推进区块高度
        
        // 验证提案状态
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded), "Proposal should be in Succeeded state");  // 断言提案状态为成功
    }
}  // 合约结束
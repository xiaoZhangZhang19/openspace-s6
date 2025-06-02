// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// 编写一个 Bank 合约，实现功能：
// 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 在 Bank 合约记录每个地址的存款金额
// 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 用数组记录存款金额的前 3 名用户

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

event withdrawETH(address, uint);

contract Bank is Ownable {  
    mapping (address => uint256) public balances;
    mapping (address => bool) public isDeposit;
    address[] public depositors;
    
    // 直接存储前三名存款人
    address[3] public topDepositors;
    
    // 链表相关变量
    struct Node {
        address user;         // 用户地址
        uint256 amount;      // 存款金额
        address next;        // 下一个节点的地址
    }
    
    // 存储所有节点
    mapping(address => Node) private nodes;
    // 头节点地址
    address private head;
    // 链表长度
    uint256 private length;
    // 最大长度
    uint256 private constant MAX_LENGTH = 10;
    
    constructor() Ownable(msg.sender) {
        // 初始化头节点
        head = address(0);
        length = 0;
    }

    // 更新前三名存款人
    function _updateTopDepositors(address depositor) private {
        uint256 amount = balances[depositor];
        
        // 检查是否需要更新前三名
        if (topDepositors[0] == address(0) || amount > balances[topDepositors[0]]) {
            // 新的第一名，其他依次后移
            topDepositors[2] = topDepositors[1];
            topDepositors[1] = topDepositors[0];
            topDepositors[0] = depositor;
        } else if (topDepositors[1] == address(0) || amount > balances[topDepositors[1]]) {
            // 新的第二名，第二名后移
            topDepositors[2] = topDepositors[1];
            topDepositors[1] = depositor;
        } else if (topDepositors[2] == address(0) || amount > balances[topDepositors[2]]) {
            // 新的第三名
            topDepositors[2] = depositor;
        }
    }
    
    // 更新前10名链表
    function _updateTop10(address depositor, uint256 amount) private {
        // 如果链表为空，直接添加
        if (length == 0) {
            nodes[depositor] = Node(depositor, amount, address(0));
            head = depositor;
            length = 1;
            return;
        }
        
        // 如果节点已存在，检查是否需要更新
        if (nodes[depositor].user != address(0)) {
            Node storage node = nodes[depositor];
            // 找到节点的前一个节点
            address prevNode = _findPrevNode(depositor);
            // 找到节点的后一个节点
            address nextNode = node.next;
            
            // 如果新金额在同一个区间内，直接更新金额
            if ((prevNode == address(0) && amount >= nodes[head].amount) ||
                (nextNode == address(0) && amount <= nodes[prevNode].amount) ||
                (amount <= nodes[prevNode].amount && amount >= nodes[nextNode].amount)) {
                node.amount = amount;
                return;
            }
            // 如果不在同一区间，需要删除后重新插入
            _removeNode(depositor);
        }
        
        // 创建新节点
        nodes[depositor] = Node(depositor, amount, address(0));
        
        // 如果新金额大于头节点，插入到头部
        if (amount > nodes[head].amount) {
            nodes[depositor].next = head;
            head = depositor;
            length = length < MAX_LENGTH ? length + 1 : MAX_LENGTH;
            return;
        }
        
        // 遍历链表找到插入位置
        address current = head;
        address prev = address(0);
        
        while (current != address(0) && nodes[current].amount >= amount) {
            prev = current;
            current = nodes[current].next;
        }
        
        // 插入新节点
        if (prev != address(0)) {
            nodes[prev].next = depositor;
        }
        nodes[depositor].next = current;
        
        // 如果超过最大长度，删除最后一个节点
        if (length >= MAX_LENGTH) {
            address last = head;
            while (nodes[last].next != address(0)) {
                last = nodes[last].next;
            }
            _removeNode(last);
        } else {
            length++;
        }
    }

    // 查找节点的前一个节点
    function _findPrevNode(address target) private view returns (address) {
        if (target == head) {
            return address(0);
        }
        
        address current = head;
        while (nodes[current].next != target) {
            current = nodes[current].next;
        }
        return current;
    }

    // 删除节点
    function _removeNode(address node) private {
        if (node == head) {
            head = nodes[node].next;
        } else {
            address prev = _findPrevNode(node);
            nodes[prev].next = nodes[node].next;
        }
        delete nodes[node];
        length--;
    }

    receive() external payable virtual {
        require(msg.value > 0, "Amount must > 0");

        if (!isDeposit[msg.sender]) {
            //防止数组重复写入
            isDeposit[msg.sender] = true;
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        
        // 更新前三名
        _updateTopDepositors(msg.sender);
        // 更新前10名链表
        _updateTop10(msg.sender, balances[msg.sender]);
    }

    function withdraw() public virtual onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "withdraw failed!");
        emit withdrawETH(msg.sender, address(this).balance);
    }

    function getTop3Depositor() public view returns (address[3] memory) {
        // 直接返回储存的前三名，不需要遍历
        return topDepositors;
    }
    
    // 获取前10名存款人
    function getTop10Depositors() public view returns (address[] memory, uint256[] memory) {
        address[] memory users = new address[](MAX_LENGTH);
        uint256[] memory amounts = new uint256[](MAX_LENGTH);
        
        address current = head;
        uint256 index = 0;
        
        // 直接遍历链表，最多遍历10个节点
        while (current != address(0) && index < MAX_LENGTH) {
            users[index] = nodes[current].user;
            amounts[index] = nodes[current].amount;
            current = nodes[current].next;
            index++;
        }
        
        return (users, amounts);
    }
}
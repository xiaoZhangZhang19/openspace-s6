// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IBank {
    function owner() external view returns (address);
    function withdraw() external ;
}

event withdrawETH(address, uint);

contract Bank is IBank {  
    address public owner;
    mapping (address => uint256) public balances;
    mapping (address => bool) public isDeposit;
    address[] public depositors;
    uint256 locked;
    
    // 直接存储前三名存款人
    address[3] public topDepositors;
    
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(msg.sender==owner,"Caller is not the owner");
        _;
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

    receive() external payable virtual {
        require(msg.value > 0, "Amount must > 0");

        if (!isDeposit[msg.sender]) {
            //防止数组重复写入
            isDeposit[msg.sender] = true;
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        
        // 每次存款后更新前三名
        _updateTopDepositors(msg.sender);
    }

    function withdraw() public onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        require(success, "withdraw failed!");
        emit withdrawETH(msg.sender, address(this).balance);
    }

    function getTop3Depositor() public view returns (address[3] memory) {
        // 直接返回储存的前三名，不需要遍历
        return topDepositors;
    }
}

contract BigBank is Bank {

    modifier etherLimit() {
        require(msg.value > 0.001 ether, "value must larger than 0.001 ether!");
        _;
    }

    receive() external payable override etherLimit{}

    // 转移owner
    function transferOwner(address _addr) public onlyOwner{
        owner = _addr;
    }

}

contract Admin {
    address public adminOwner;

    constructor() {
        adminOwner = msg.sender;
    }

    // 在任何情况下接收以太币
    receive() external payable {}

    modifier onlyOwner() {
        require(msg.sender == adminOwner, "Caller is not the owner");
        _;
    }

    // 通过传入BigBank合约的地址来调用withdraw方法
    function adminWithdraw(IBank bank) public {
        require(msg.sender == adminOwner, "Only owner can call this method");
        bank.withdraw();
    }

    // 防止钱被锁死在admin合约中
    function withdraw() public onlyOwner{
        (bool success,) = payable(adminOwner).call{value: address(this).balance}("");
        require(success, "Withdraw failed!");
    }

}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// 编写一个 Bank 合约，实现功能：
// 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
// 在 Bank 合约记录每个地址的存款金额
// 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
// 用数组记录存款金额的前 3 名用户

event withdrawETH(address, uint);

contract Bank {
    address public owner;
    mapping (address => uint256) public balances;
    mapping (address => bool) public isDeposit;
    address[] public depositors;
    uint256 public totalETH;
    
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(msg.sender==owner,"Caller is not the owner");
        _;
    }

    receive() external payable {
        require(msg.value > 0, "Amount must > 0");

        if (!isDeposit[msg.sender]) {
            //防止数组重复写入
            isDeposit[msg.sender] = true;
            depositors.push(msg.sender);
        }
        balances[msg.sender] += msg.value;
        totalETH += msg.value;
        
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= totalETH, "Not enough funds!");
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "withdraw failed!");
        totalETH -= amount;
        emit withdrawETH(msg.sender, amount);
    }

    function getTop3Depositor() public view returns (address[3] memory){
        //由于top3Depositors需要被修改，不能使用calldata
        address[3] memory top3Depositors;
        for (uint256 i = 0; i < depositors.length; i++) {
            if (top3Depositors[0] == address(0) || balances[depositors[i]] > balances[top3Depositors[0]]) {
                // 依次往后挪
                top3Depositors[2] = top3Depositors[1];
                top3Depositors[1] = top3Depositors[0];
                top3Depositors[0] = depositors[i];
            } else if (top3Depositors[1] == address(0) || balances[depositors[i]] > balances[top3Depositors[1]] ) {
                top3Depositors[2] = top3Depositors[1];
                top3Depositors[1] = depositors[i];
            } else if (top3Depositors[2] == address(0) || balances[depositors[i]] > balances[top3Depositors[2]] ){
                top3Depositors[2] = depositors[i];
            }
        }
        return top3Depositors;
    }


}

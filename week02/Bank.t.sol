pragma solidity 0.8.29;


// 测试Case 包含：
// 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
// 检查存款金额的前 3 名用户时候正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
// 检查只有管理员可取款，其他人不可以取款。

import {Test} from "forge-std/Test.sol";
import {Bank} from "src/Bank.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

error OwnableUnauthorizedAccount(address account);
event withdrawETH(address, uint);

contract BankTest is Test {
    Bank public bank;
    uint256 sepoliaFork;
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    function setUp() public {
        //设置owner
        vm.prank(owner);
        bank = new Bank();
        //读取.env中的配置SEPOLIA_RPC_URL
        string memory sepoliaRpcUrl = vm.envString("ETH_RPC_URL");
        sepoliaFork = vm.createSelectFork(sepoliaRpcUrl);
        //设置owner的余额
        deal(owner, 10000 ether);
        //设置user1的余额
        deal(user1, 10000 ether);
        //设置user2的余额
        deal(user2, 10000 ether);
        //设置user3的余额
        deal(user3, 10000 ether);
        //设置user4的余额
        deal(user4, 10000 ether);
        //设置bank合约的余额
        deal(address(bank), 10000 ether);
    }

    function test_transferETH() public {
        //模拟切换到sepoliaFork
        vm.selectFork(sepoliaFork);
        //断言当前选择的fork是sepoliaFork
        assertEq(vm.activeFork(), sepoliaFork);
        //断言owner的余额
        assertEq(owner.balance, 10000 ether);
        //断言user1的余额
        assertEq(user1.balance, 10000 ether);
        //断言user2的余额
        assertEq(user2.balance, 10000 ether);
        //断言user3的余额
        assertEq(user3.balance, 10000 ether);
        //断言user4的余额
        assertEq(user4.balance, 10000 ether);
        //owner向bank合约转账
        vm.prank(owner);
        (bool success,) = address(bank).call{value: 1 ether}("");
        //断言转账成功
        assertEq(success, true);
        //断言owner的余额
        assertEq(owner.balance, 9999 ether);
        //断言bank合约的余额
        assertEq(address(bank).balance, 10001 ether);
    }

    function test_withdraw() public {
        vm.startPrank(owner);
        //断言事件是否正确发送
        vm.expectEmit(true, true, false, false);
        emit withdrawETH(owner, address(bank).balance);
        bank.withdraw();
        vm.stopPrank();
        //断言owner的余额
        assertEq(owner.balance, 20000 ether);
        //断言bank合约的余额
        assertEq(address(bank).balance, 0 ether);
    }

    function test_withdrawFail() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, user1));
        bank.withdraw();
    }

    function test_getTop3Depositor() public {
        vm.prank(user1);
        (bool success1,) = address(bank).call{value: 1 ether}("");
        assertEq(success1, true);
        vm.prank(user2);
        (bool success2,) = address(bank).call{value: 2 ether}("");
        assertEq(success2, true);
        vm.prank(user3);
        (bool success3,) = address(bank).call{value: 3 ether}("");
        assertEq(success3, true);
        vm.prank(user4);
        (bool success4,) = address(bank).call{value: 4 ether}("");
        assertEq(success4, true);
        //断言前三名
        address[3] memory top3 = bank.getTop3Depositor();
        assertEq(top3[0], user4);
        assertEq(top3[1], user3);
        assertEq(top3[2], user2);
    }

    function test_transferETHMultipleTimes() public {
        vm.startPrank(user1);
        (bool success1,) = address(bank).call{value: 1 ether}("");
        assertEq(success1, true);
        (bool success2,) = address(bank).call{value: 2 ether}("");
        assertEq(success2, true);
        vm.stopPrank();
        assertEq(address(bank).balance, 10003 ether);
    }

    function testFuzz_transferETHMultipleTimes(uint256 amount) public {
        amount = bound(amount, 1 ether, 10000 ether);
        vm.startPrank(user1);
        (bool success1,) = address(bank).call{value: amount}("");
        assertEq(success1, true);
        vm.stopPrank();
        assertEq(address(bank).balance, amount + 10000 ether);
    }
}
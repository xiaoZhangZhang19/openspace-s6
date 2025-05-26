// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/Vesting/Vesting.sol";
import "../../src/Vesting/MockERC20.sol";

/**
 * @title VestingTest
 * @dev Vesting 合约的完整测试套件
 */
contract VestingTest is Test {
    Vesting public vesting;
    MockERC20 public token;
    
    address public beneficiary = address(0x1234);
    address public deployer = address(this);
    
    // 常量定义
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18; // 100万代币
    uint256 public constant CLIFF_DURATION = 365 days; // 12个月悬崖期
    uint256 public constant VESTING_DURATION = 730 days; // 24个月线性释放期
    
    // 时间常量 - 使用更精确的计算
    uint256 public constant ONE_MONTH = VESTING_DURATION / 24; // 24个月的线性释放期除以24
    uint256 public constant ONE_DAY = 1 days;
    
    // 事件定义
    event TokensReleased(uint256 amount);
    
    function setUp() public {
        // 部署模拟 ERC20 代币
        token = new MockERC20("Test Token", "TEST", 18);
        
        // 铸造代币给部署者
        token.mint(deployer, TOTAL_AMOUNT);
        
        // 部署 Vesting 合约
        vesting = new Vesting(
            beneficiary,
            address(token),
            CLIFF_DURATION,
            VESTING_DURATION,
            TOTAL_AMOUNT
        );
        
        // 将代币转移到 Vesting 合约
        token.transfer(address(vesting), TOTAL_AMOUNT);
        
        // 验证代币转移成功
        assertEq(token.balanceOf(address(vesting)), TOTAL_AMOUNT);
    }
    
    /**
     * @dev 测试合约初始状态
     */
    function testInitialState() public view {
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.cliffDuration(), CLIFF_DURATION);
        assertEq(vesting.vestingDuration(), VESTING_DURATION);
        assertEq(vesting.totalAmount(), TOTAL_AMOUNT);
        assertEq(vesting.released(), 0);
        
        // 检查初始可释放数量为 0
        assertEq(vesting.releasable(), 0);
    }
    
    /**
     * @dev 测试悬崖期内无法释放代币
     */
    function testNoReleaseBeforeCliff() public {
        uint256 startTime = vesting.startTime();
        
        // 测试第 1 天
        vm.warp(startTime + ONE_DAY);
        assertEq(vesting.releasable(), 0);
        
        // 测试第 6 个月（180天）
        vm.warp(startTime + 180 days);
        assertEq(vesting.releasable(), 0);
        
        // 测试第 11 个月（330天），仍在悬崖期内
        vm.warp(startTime + 330 days);
        assertEq(vesting.releasable(), 0);
        
        // 测试悬崖期结束前一天（364天）
        vm.warp(startTime + CLIFF_DURATION - 1 days);
        assertEq(vesting.releasable(), 0);
        
        // 尝试释放应该失败
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
    
    /**
     * @dev 测试悬崖期结束时的释放
     */
    function testReleaseAtCliffEnd() public {
        // 移动到悬崖期结束
        vm.warp(block.timestamp + CLIFF_DURATION);
        
        // 悬崖期结束时，可释放数量应该为 0（线性释放还未开始）
        assertEq(vesting.releasable(), 0);
        
        // 尝试释放应该失败
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
    
    /**
     * @dev 测试线性释放开始后的第一个月
     */
    function testFirstMonthAfterCliff() public {
        // 移动到悬崖期结束后第一个月
        vm.warp(block.timestamp + CLIFF_DURATION + ONE_MONTH);
        
        // 计算期望的释放数量（1/24 的总量）
        uint256 expectedRelease = TOTAL_AMOUNT / 24;
        
        assertEq(vesting.releasable(), expectedRelease);
        
        // 测试释放
        vm.prank(beneficiary);
        vm.expectEmit(true, true, true, true);
        emit TokensReleased(expectedRelease);
        vesting.release();
        
        // 验证释放结果
        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(vesting.released(), expectedRelease);
        assertEq(vesting.releasable(), 0); // 释放后应该为 0
    }
    
    /**
     * @dev 测试多次释放
     */
    function testMultipleReleases() public {
        // 第一次释放：悬崖期后第一个月
        vm.warp(block.timestamp + CLIFF_DURATION + ONE_MONTH);
        uint256 firstRelease = TOTAL_AMOUNT / 24;
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), firstRelease);
        assertEq(vesting.released(), firstRelease);
        
        // 第二次释放：再过 6 个月
        vm.warp(block.timestamp + 6 * ONE_MONTH);
        uint256 expectedTotal = (TOTAL_AMOUNT * 7) / 24; // 7个月的总释放量
        uint256 secondRelease = expectedTotal - firstRelease;
        
        assertEq(vesting.releasable(), secondRelease);
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), expectedTotal);
        assertEq(vesting.released(), expectedTotal);
    }
    
    /**
     * @dev 测试线性释放期中间的释放
     */
    function testMidVestingRelease() public {
        // 移动到悬崖期后第 12 个月（线性释放期的一半）
        vm.warp(block.timestamp + CLIFF_DURATION + 12 * ONE_MONTH);
        
        // 期望释放总量的一半
        uint256 expectedRelease = TOTAL_AMOUNT / 2;
        
        assertEq(vesting.releasable(), expectedRelease);
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(vesting.released(), expectedRelease);
    }
    
    /**
     * @dev 测试线性释放期结束时的完全释放
     */
    function testFullVestingComplete() public {
        // 移动到线性释放期结束
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION);
        
        // 应该能释放所有剩余代币
        assertEq(vesting.releasable(), TOTAL_AMOUNT);
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
        assertEq(vesting.released(), TOTAL_AMOUNT);
        assertEq(vesting.releasable(), 0);
        
        // 再次尝试释放应该失败
        vm.prank(beneficiary);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
    
    /**
     * @dev 测试超过释放期后的行为
     */
    function testAfterVestingComplete() public {
        // 移动到释放期结束后很久
        vm.warp(block.timestamp + CLIFF_DURATION + VESTING_DURATION + 365 days);
        
        // 仍应该能释放所有代币
        assertEq(vesting.releasable(), TOTAL_AMOUNT);
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), TOTAL_AMOUNT);
        assertEq(vesting.released(), TOTAL_AMOUNT);
    }
    
    /**
     * @dev 测试精确的月度释放计算
     */
    function testPreciseMonthlyRelease() public {
        // 测试每个月的精确释放量
        uint256 startTime = block.timestamp + CLIFF_DURATION;
        
        for (uint256 month = 1; month <= 24; month++) {
            vm.warp(startTime + month * ONE_MONTH);
            
            uint256 expectedTotal = (TOTAL_AMOUNT * month) / 24;
            uint256 currentReleasable = vesting.releasable();
            uint256 expectedReleasable = expectedTotal - vesting.released();
            
            assertEq(currentReleasable, expectedReleasable, 
                string(abi.encodePacked("Month ", vm.toString(month), " releasable amount mismatch")));
        }
    }
    
    /**
     * @dev 测试非受益人调用释放函数
     */
    function testNonBeneficiaryCanCallRelease() public {
        // 移动到可释放时间
        vm.warp(block.timestamp + CLIFF_DURATION + ONE_MONTH);
        
        uint256 expectedRelease = TOTAL_AMOUNT / 24;
        
        // 非受益人也可以调用 release 函数，但代币会发送给受益人
        vm.prank(address(0x9999));
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(token.balanceOf(address(0x9999)), 0);
    }
    
    /**
     * @dev 测试 getVestingInfo 函数
     */
    function testGetVestingInfo() public {
        (
            address _beneficiary,
            address _token,
            uint256 _startTime,
            uint256 _cliffDuration,
            uint256 _vestingDuration,
            uint256 _totalAmount,
            uint256 _released
        ) = vesting.getVestingInfo();
        
        assertEq(_beneficiary, beneficiary);
        assertEq(_token, address(token));
        assertGt(_startTime, 0);
        assertEq(_cliffDuration, CLIFF_DURATION);
        assertEq(_vestingDuration, VESTING_DURATION);
        assertEq(_totalAmount, TOTAL_AMOUNT);
        assertEq(_released, 0);
    }
    
    /**
     * @dev 测试构造函数的参数验证
     */
    function testConstructorValidation() public {
        // 测试零地址受益人
        vm.expectRevert("Beneficiary cannot be zero address");
        new Vesting(address(0), address(token), CLIFF_DURATION, VESTING_DURATION, TOTAL_AMOUNT);
        
        // 测试零地址代币
        vm.expectRevert("Token cannot be zero address");
        new Vesting(beneficiary, address(0), CLIFF_DURATION, VESTING_DURATION, TOTAL_AMOUNT);
        
        // 测试零悬崖期
        vm.expectRevert("Cliff duration must be greater than 0");
        new Vesting(beneficiary, address(token), 0, VESTING_DURATION, TOTAL_AMOUNT);
        
        // 测试零释放期
        vm.expectRevert("Vesting duration must be greater than 0");
        new Vesting(beneficiary, address(token), CLIFF_DURATION, 0, TOTAL_AMOUNT);
        
        // 测试零总量
        vm.expectRevert("Total amount must be greater than 0");
        new Vesting(beneficiary, address(token), CLIFF_DURATION, VESTING_DURATION, 0);
    }
    
    /**
     * @dev Fuzz 测试：随机时间点的释放计算
     */
    function testFuzzReleaseCalculation(uint256 timeOffset) public {
        // 限制时间偏移在合理范围内
        timeOffset = bound(timeOffset, 0, CLIFF_DURATION + VESTING_DURATION + 365 days);
        
        vm.warp(block.timestamp + timeOffset);
        
        uint256 releasableAmount = vesting.releasable();
        
        if (timeOffset < CLIFF_DURATION) {
            // 悬崖期内应该为 0
            assertEq(releasableAmount, 0);
        } else if (timeOffset >= CLIFF_DURATION + VESTING_DURATION) {
            // 释放期结束后应该为总量减去已释放量
            assertEq(releasableAmount, TOTAL_AMOUNT - vesting.released());
        } else {
            // 线性释放期内的计算
            uint256 elapsedSinceCliff = timeOffset - CLIFF_DURATION;
            uint256 expectedVested = (TOTAL_AMOUNT * elapsedSinceCliff) / VESTING_DURATION;
            uint256 expectedReleasable = expectedVested - vesting.released();
            assertEq(releasableAmount, expectedReleasable);
        }
    }
} 
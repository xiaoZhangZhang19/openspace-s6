// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InscriptionFactory.sol";
import "../src/InscriptionToken.sol";

contract InscriptionTest is Test {
    InscriptionFactory public factory;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        // Add ETH to test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(address(this), 100 ether);
        
        factory = new InscriptionFactory();
        factory.setFee(0.01 ether);
    }

    function testDeployInscription() public {
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );
        vm.stopPrank();

        address tokenAddress = factory.inscriptions("TEST");
        assertTrue(tokenAddress != address(0));
        
        InscriptionToken token = InscriptionToken(payable(tokenAddress));
        assertEq(token.symbol(), "TEST");
        assertEq(token.creator(), user1);
        
        // 验证费用存在合约中
        assertEq(address(factory).balance, 0.01 ether);
    }

    function testMintInscription() public {
        // 首先部署代币
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );
        
        // 获取代币地址
        address tokenAddress = factory.inscriptions("TEST");
        InscriptionToken token = InscriptionToken(payable(tokenAddress));
        
        // creator (user1) 铸造代币
        token.mintTo{value: 0.1 ether}(user2);
        vm.stopPrank();

        // 验证铸造结果
        assertEq(token.balanceOf(user2), 1000);
        assertEq(token.totalMinted(), 1000);
        
        // 验证铸造费用存在代币合约中
        assertEq(address(token).balance, 0.1 ether);
    }

    function testMintInscriptionViaFactory() public {
        // 首先部署代币
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );
        vm.stopPrank();

        // 记录铸造前的余额
        uint256 factoryBalanceBefore = address(factory).balance;
        address tokenAddress = factory.inscriptions("TEST");
        uint256 tokenBalanceBefore = address(tokenAddress).balance;
        uint256 userBalanceBefore = user2.balance;

        // user2 通过工厂合约铸造代币
        vm.startPrank(user2);
        // 铸造价格是 0.1 ether，平台费用是 10%，所以总共需要 0.11 ether
        factory.mintInscription{value: 0.11 ether}("TEST");
        vm.stopPrank();

        // 获取代币合约
        InscriptionToken token = InscriptionToken(payable(tokenAddress));

        // 验证代币铸造结果
        assertEq(token.balanceOf(user2), 1000);
        assertEq(token.totalMinted(), 1000);

        // 验证费用分配
        // 平台费用存在工厂合约中
        assertEq(address(factory).balance - factoryBalanceBefore, 0.01 ether);
        // 铸造费用存在代币合约中
        assertEq(address(token).balance - tokenBalanceBefore, 0.1 ether);
        // 用户支付了总费用
        assertEq(userBalanceBefore - user2.balance, 0.11 ether);
    }

    function testWithdrawFactoryFees() public {
        // 部署代币产生费用
        vm.prank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );

        // 记录提取前的余额
        uint256 ownerBalanceBefore = owner.balance;
        uint256 factoryBalanceBefore = address(factory).balance;

        // 工厂所有者提取费用
        factory.withdraw();

        // 验证费用提取
        assertEq(owner.balance - ownerBalanceBefore, factoryBalanceBefore);
        assertEq(address(factory).balance, 0);
    }

    function testWithdrawTokenFees() public {
        // 部署并铸造代币
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );
        
        address tokenAddress = factory.inscriptions("TEST");
        InscriptionToken token = InscriptionToken(payable(tokenAddress));
        token.mintTo{value: 0.1 ether}(user2);
        
        // 记录提取前的余额
        uint256 creatorBalanceBefore = user1.balance;
        uint256 tokenBalanceBefore = address(token).balance;

        // 代币创建者提取费用
        token.withdraw();
        vm.stopPrank();

        // 验证费用提取
        assertEq(user1.balance - creatorBalanceBefore, tokenBalanceBefore);
        assertEq(address(token).balance, 0);
    }

    function test_RevertWhen_NonOwnerWithdrawFactoryFees() public {
        vm.prank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );

        // 非所有者尝试提取费用
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user2)
        );
        factory.withdraw();
    }

    function test_RevertWhen_NonCreatorWithdrawTokenFees() public {
        vm.prank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000000,
            1000,
            0.1 ether
        );

        address tokenAddress = factory.inscriptions("TEST");
        InscriptionToken token = InscriptionToken(payable(tokenAddress));

        // 非创建者尝试提取费用
        vm.prank(user2);
        vm.expectRevert("Only creator can withdraw");
        token.withdraw();
    }

    function testMintSupplyLimit() public {
        // 部署代币，设置总供应量为 3000，每次铸造 1000
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            3000,  // totalSupplyLimit
            1000,  // perMint
            0.1 ether
        );
        
        address tokenAddress = factory.inscriptions("TEST");
        InscriptionToken token = InscriptionToken(payable(tokenAddress));
        
        // 第一次铸造
        token.mintTo{value: 0.1 ether}(user2);
        assertEq(token.totalMinted(), 1000);
        assertEq(token.balanceOf(user2), 1000);
        
        // 第二次铸造
        token.mintTo{value: 0.1 ether}(user2);
        assertEq(token.totalMinted(), 2000);
        assertEq(token.balanceOf(user2), 2000);
        
        // 第三次铸造
        token.mintTo{value: 0.1 ether}(user2);
        assertEq(token.totalMinted(), 3000);
        assertEq(token.balanceOf(user2), 3000);
        
        // 第四次铸造应该失败，因为超过了总供应量
        vm.expectRevert("Exceeds total supply");
        token.mintTo{value: 0.1 ether}(user2);
        
        vm.stopPrank();
    }

    function testPerMintAmount() public {
        // 部署代币，验证每次铸造的数量正确
        vm.startPrank(user1);
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            10000,  // totalSupplyLimit
            2500,   // perMint
            0.1 ether
        );
        
        address tokenAddress = factory.inscriptions("TEST");
        InscriptionToken token = InscriptionToken(payable(tokenAddress));
        
        // 通过工厂合约铸造
        vm.stopPrank();
        vm.startPrank(user2);
        factory.mintInscription{value: 0.11 ether}("TEST");  // 0.1 + 10% 费用
        
        // 验证铸造数量正确
        assertEq(token.totalMinted(), 2500);
        assertEq(token.balanceOf(user2), 2500);
        assertEq(token.perMintAmount(), 2500);
        
        // 再次铸造，验证数量累加正确
        factory.mintInscription{value: 0.11 ether}("TEST");
        assertEq(token.totalMinted(), 5000);
        assertEq(token.balanceOf(user2), 5000);
        
        vm.stopPrank();
    }

    function test_RevertWhen_InvalidMintAmount() public {
        // 测试无效的铸造数量参数
        vm.startPrank(user1);
        
        // perMint 为 0
        vm.expectRevert("Invalid perMint amount");
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000,
            0,  // perMint 不能为 0
            0.1 ether
        );
        
        // perMint 大于 totalSupplyLimit
        vm.expectRevert("Invalid perMint amount");
        factory.deployInscription{value: 0.01 ether}(
            "TEST",
            1000,
            1001,  // perMint 不能大于 totalSupplyLimit
            0.1 ether
        );
        
        vm.stopPrank();
    }

    receive() external payable {}
} 
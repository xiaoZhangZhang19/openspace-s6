pragma solidity ^0.8.0;

import {MyTokenWithCallback} from "../src/MyTokenWithCallback.sol";
import {TokenBank2} from "../src/TokenBank2.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract TokenBank2Test is Test {
    MyTokenWithCallback public token;
    TokenBank2 public bank;
    address public tokenOwner = makeAddr("tokenOwner");
    address public tokenBankOwner = makeAddr("tokenBankOwner");

    function setUp() public {
        vm.prank(tokenOwner);
        token = new MyTokenWithCallback("TestToken", "TT", 1000);
        vm.prank(tokenBankOwner);
        bank = new TokenBank2(address(token));
    }

    function test_transferWithCallback() public {
        vm.prank(tokenOwner);
        token.transferWithCallback(address(bank), 100);
    }
}
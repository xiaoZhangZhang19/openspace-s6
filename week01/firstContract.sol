// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract Counter {
    uint counter;

    function get() public view  returns (uint256) {
        return counter;
    }

    function add(uint256 x) public {
        counter += x;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/BalanceCheckBug.sol";

contract BalanceCheckBugTest is Test {
    BalanceCheckBug vault;
    address user1;
    address user2;

    function setUp() public {
        vault = new BalanceCheckBug();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function testDeposit() public {
        vm.prank(user1);
        vault.deposit{value: 1 ether}();
        assertEq(vault.users(user1), 1 ether);
    }

    function testDepositAndWithdraw() public {
       
        vm.prank(user1);
        vault.deposit{value: 5 ether}();
        assertEq(vault.users(user1), 5 ether);

        
        uint256 balanceBefore = user1.balance;
        vm.prank(user1);
        vault.withdraw(2 ether);

        
        assertEq(user1.balance, balanceBefore + 2 ether);
        assertEq(vault.users(user1), 3 ether);
    }

    function testOverwriteDepositBug() public {
        
        vm.prank(user1);
        vault.deposit{value: 5 ether}();
        assertEq(vault.users(user1), 5 ether);

       
        vm.prank(user1);
        vault.deposit{value: 1 ether}();

        
        assertEq(vault.users(user1), 1 ether, "BUG: Should be 6 ether");
        assertEq(address(vault).balance, 6 ether);
    }
}


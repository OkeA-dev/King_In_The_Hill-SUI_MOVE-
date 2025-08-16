// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.4.11;

import {Test, console} from "forge-std/Test.sol";
import {IcxToken} from "../src/A11.sol";

contract CounterTest is Test {
    address wallet;
    address attacker;
    IcxToken token;
    uint256 constant INITIALBALANCE = 100 * 10**18;


    function setup() external {

        wallet = makeAddr("wallet");
        attacker = makeAddr("attacker");

        token = new IcxToken(INITIALBALANCE, wallet);
    }

    function test_attackerCanPauseTokenTransfer() external {

        vm.prank(attacker);
        token.disableTokenTransfer();

        // wallet can't enable or disable transfer but anyone can do.
        vm.prank(wallet);
        vm.expectRevert();
        token.enableTokenTransfer();
    }
}

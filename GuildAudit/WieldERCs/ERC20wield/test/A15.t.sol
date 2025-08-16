// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.4.11;

import {Test, console} from "forge-std/Test.sol";
import {MorphToken} from "../src/A15.sol";

contract CounterTest is Test {
    address owner;
    address attacker;

    function setUp() external {
        owner = makeAddr("owner");
        attacker = makeAdd("owner");
        MorphToken token = new MorphToken();

        //owner initialize of owner at deployment 
        vm.prank(owner);
        token.MorphToken();
    }

    function test_attackOwner() external {
        vm.prank(attacker);
        token.owned();

        assertEq(token.owner() == attacker);

        //Recommeded mitigation: change owned in to constructor in Owned contract.
    }
   

}


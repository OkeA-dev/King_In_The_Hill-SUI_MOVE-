// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BalanceCheckBug {
    address public owner;
    mapping (address => uint) public users;

    constructor() {
        owner = msg.sender;
    }

   
    function deposit() external payable {
        users[msg.sender] = msg.value;
    }

   
    function withdraw(uint amount) external {
        require(users[msg.sender] >= amount, "Insufficient Balance");

        // Sends fixed amount to the caller if threshold is met
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Withdraw failed");

        users[msg.sender] -= amount;
        
    }
}

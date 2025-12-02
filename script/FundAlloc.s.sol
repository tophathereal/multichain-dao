// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

contract FundAlloc is Script {
    address payable[] public targets = [
        payable(0xF99d404c92A19201F4da51fD4AbafCaa9518E185),
        payable(0xc84649BB3345e773AecE0240eB38fB958F2EE321),
        payable(0xeAC596bdA9F0025095FFa942563CB23290e7ab9c),
        payable(0x39215A373D5b03A192BF898ef1A821d5713a0894),
        payable(0x3E2C502739a24D23A0B522d26958C69614Dac833),
        payable(0x0bd60A0400E6135D2447756a68F8756E5ABFdE49)
    ];
    
    // Amount to send each, in wei: 0x3635C9ADC5DEA0000000 = 1000 ether
    uint256 constant amountPerAddress = 10 ether;

    function run() external {
        vm.startBroadcast();

        for (uint256 i = 0; i < targets.length; i++) {
            // Transfer amountPerAddress ETH to each target
            (bool sent,) = targets[i].call{value: amountPerAddress}("");
            require(sent, "Failed to send ETH");
        }

        vm.stopBroadcast();
    }

    // Allow contract to receive ETH (not strictly needed here)
    receive() external payable {}
}


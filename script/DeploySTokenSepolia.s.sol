// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {SToken} from "../src/SToken.sol";
import {STokenBridge} from "../src/STokenBridge.sol";

contract DeploySTokenSepolia is Script {
    function run() external {
        // Load config from environment variables
        uint256 deployerKey    = vm.envUint("PRIVATE_KEY");
        address relayerAddress = vm.envAddress("RELAYER_ADDRESS");
        
        // Remote chain is local (1337)
        uint256 remoteChainId = 1337;

        vm.startBroadcast(deployerKey);

        // 1. Deploy STokenBridge first (no token address needed yet)
        STokenBridge bridge = new STokenBridge(remoteChainId, relayerAddress);
        console2.log("Step 1: Deployed STokenBridge:", address(bridge));

        // 2. Deploy SToken with bridge address
        SToken sToken = new SToken(address(bridge));
        console2.log("Step 2: Deployed SToken:", address(sToken));

        // 3. Wire bridge to token
        bridge.setToken(address(sToken));
        console2.log("Step 3: Called bridge.setToken(sToken)");

        vm.stopBroadcast();

        // Log deployment details
        console2.log("");
        console2.log("=== SToken + Bridge Deployment to Sepolia ===");
        console2.log("STokenBridge:", address(bridge));
        console2.log("SToken (STK):", address(sToken));
        console2.log("Relayer:", relayerAddress);
        console2.log("Remote Chain ID:", remoteChainId);
        console2.log("Deployer:", msg.sender);
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        console2.log("Deployment complete!");
        console2.log("");
        console2.log("Add to relayer .env:");
        console2.log("BRIDGE_B_ADDRESS=%s", address(bridge));
    }
}

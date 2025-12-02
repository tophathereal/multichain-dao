// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {MultiTokenGovernor} from "../src/MyGovernor.sol";
import {SToken} from "../src/SToken.sol";
import {STokenBridge} from "../src/STokenBridge.sol";
import {NSToken} from "../src/NSToken.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployMultiTokenGovernor is Script {
    function run() external {
        // Load config from environment variables
        uint256 deployerKey    = vm.envUint("PRIVATE_KEY");
        address initialOwner   = vm.envAddress("INITIAL_OWNER");   // owner of NSToken
        address relayerAddress = vm.envAddress("RELAYER_ADDRESS"); // relayer for bridge

        // Remote chain is Sepolia (11155111)
        uint256 remoteChainId = 11155111;

        vm.startBroadcast(deployerKey);

        // 1. Deploy STokenBridge first (for cross-chain functionality)
        STokenBridge bridge = new STokenBridge(remoteChainId, relayerAddress);
        console2.log("Step 1: Deployed STokenBridge:", address(bridge));

        // 2. Deploy SToken with bridge address
        SToken sToken = new SToken(address(bridge));
        console2.log("Step 2: Deployed SToken:", address(sToken));

        // 3. Wire bridge to token
        bridge.setToken(address(sToken));
        console2.log("Step 3: Called bridge.setToken(sToken)");

        // 4. Deploy NSToken (non-stock governance token)
        NSToken nsToken = new NSToken(initialOwner);
        console2.log("Step 4: Deployed NSToken:", address(nsToken));

        // 5. Prepare IVotes array for the governor
        IVotes[] memory voteTokens = new IVotes[](2);
        voteTokens[0] = IVotes(address(sToken));
        voteTokens[1] = IVotes(address(nsToken));

        // 6. Deploy governor with both tokens
        MultiTokenGovernor governor = new MultiTokenGovernor(voteTokens);
        console2.log("Step 5: Deployed MultiTokenGovernor:", address(governor));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("");
        console2.log("=== Full Governance System Deployment (Local Chain) ===");
        console2.log("STokenBridge:", address(bridge));
        console2.log("SToken (STK):", address(sToken));
        console2.log("NSToken (NSTK):", address(nsToken));
        console2.log("MultiTokenGovernor:", address(governor));
        console2.log("Relayer:", relayerAddress);
        console2.log("NSToken Owner:", initialOwner);
        console2.log("Remote Chain ID:", remoteChainId);
        console2.log("Deployer:", msg.sender);
        console2.log("Chain ID:", block.chainid);
        console2.log("");
        console2.log("Deployment complete!");
        console2.log("");
        console2.log("Add to relayer .env:");
        console2.log("BRIDGE_A_ADDRESS=%s", address(bridge));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";
import {VotesOFT} from "../src/VotesOFT.sol";
import {NSToken} from "../src/NSToken.sol";
import {ERC6909VotesToken} from "../src/ERC6909VotesToken.sol";
import {MultiTokenGovernor} from "../src/MyGovernor.sol";
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title DeployVotesOFT
 * @notice Deployment script for VotesOFT on Sepolia and Amoy testnets
 * @dev On Sepolia, also deploys NSToken or ERC6909VotesToken (based on env) and MultiTokenGovernor
 * @dev Set USE_ERC6909=true in .env to deploy ERC6909VotesToken instead of NSToken
 */
contract DeployVotesOFT is Script {
    // LayerZero V2 Endpoint addresses
    address constant LZ_ENDPOINT_SEPOLIA = 0x6EDCE65403992e310A62460808c4b910D972f10f;
    address constant LZ_ENDPOINT_AMOY = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // LayerZero V2 Endpoint IDs
    uint32 constant EID_SEPOLIA = 40161;
    uint32 constant EID_AMOY = 40267;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy VotesOFT on both chains
        VotesOFT votesToken = new VotesOFT(
            "VotesOFT",
            "vOFT",
            _getLzEndpoint(),
            deployer,  // delegate
            deployer   // owner
        );

        console2.log("VotesOFT deployed at:", address(votesToken));
        console2.log("VotesOFT balance:", votesToken.balanceOf(deployer));

        // On Sepolia, also deploy second token and MultiTokenGovernor
        if (block.chainid == 11155111) {
            console2.log("\n=== Deploying Sepolia Governance System ===");
            
            // Check if we should use ERC6909 token (default: false)
            bool useERC6909 = vm.envOr("USE_ERC6909", false);
            
            address secondTokenAddress;
            string memory secondTokenName;

            if (useERC6909) {
                console2.log("Deploying ERC6909VotesToken...");
                
                // Deploy ERC6909VotesToken
                ERC6909VotesToken erc6909Token = new ERC6909VotesToken(
                    "Governance Voting Token",
                    "Proposer Permission Token"
                );
                
                secondTokenAddress = address(erc6909Token);
                secondTokenName = "ERC6909VotesToken";
                
                // Mint some voting tokens (ID 0) to deployer
                uint256 initialVotingSupply = vm.envOr("ERC6909_INITIAL_SUPPLY", uint256(1000000 ether));
                erc6909Token.mintVoting(deployer, initialVotingSupply);
                
                // Optionally grant proposer permission (ID 1)
                bool grantProposer = vm.envOr("GRANT_PROPOSER", true);
                if (grantProposer) {
                    erc6909Token.grantProposer(deployer);
                    console2.log("Granted proposer permission to:", deployer);
                }
                
                console2.log("ERC6909VotesToken deployed at:", address(erc6909Token));
                console2.log("Voting balance (ID 0):", erc6909Token.balanceOf(deployer, 0));
                console2.log("Proposer balance (ID 1):", erc6909Token.balanceOf(deployer, 1));
                console2.log("Voting power:", erc6909Token.getVotes(deployer));
                
            } else {
                console2.log("Deploying NSToken...");
                
                // Deploy NSToken
                NSToken nsToken = new NSToken(deployer);
                
                secondTokenAddress = address(nsToken);
                secondTokenName = "NSToken";
                
                console2.log("NSToken deployed at:", address(nsToken));
                console2.log("NSToken balance:", nsToken.balanceOf(deployer));
            }

            // Create array of voting tokens for governor
            IVotes[] memory voteTokens = new IVotes[](2);
            voteTokens[0] = IVotes(address(votesToken));
            voteTokens[1] = IVotes(secondTokenAddress);

            // Deploy MultiTokenGovernor
            MultiTokenGovernor governor = new MultiTokenGovernor(voteTokens);
            console2.log("MultiTokenGovernor deployed at:", address(governor));
            console2.log("Governor name:", governor.name());
            console2.log("Governor voting delay:", governor.votingDelay());
            console2.log("Governor voting period:", governor.votingPeriod());
            console2.log("Number of vote tokens:", governor.voteTokensLength());

            console2.log("\n=== Deployment Summary (Sepolia) ===");
            console2.log("VotesOFT:", address(votesToken));
            console2.log(string.concat(secondTokenName, ":"), secondTokenAddress);
            console2.log("Governor:", address(governor));
            console2.log("Token Type:", useERC6909 ? "ERC6909VotesToken" : "NSToken");
        }

        vm.stopBroadcast();
    }

    function _getLzEndpoint() internal view returns (address) {
        if (block.chainid == 11155111) return LZ_ENDPOINT_SEPOLIA;
        if (block.chainid == 80002) return LZ_ENDPOINT_AMOY;
        revert("Unsupported chain");
    }
}

/**
 * @title SetPeers
 * @notice Configures peer connections between VotesOFT deployments
 * @dev Run after deploying to both chains
 */
contract SetPeers is Script {
    uint32 constant EID_SEPOLIA = 40161;
    uint32 constant EID_AMOY = 40267;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address localOft = vm.envAddress("LOCAL_OFT");
        address remoteOft = vm.envAddress("REMOTE_OFT");

        vm.startBroadcast(deployerPrivateKey);

        VotesOFT oft = VotesOFT(localOft);
        uint32 remoteEid = _getRemoteEid();

        // Convert address to bytes32 for setPeer
        bytes32 remotePeer = bytes32(uint256(uint160(remoteOft)));
        
        oft.setPeer(remoteEid, remotePeer);
        
        console2.log("Peer set for EID:", remoteEid);
        console2.log("Remote OFT (bytes32):", vm.toString(remotePeer));

        vm.stopBroadcast();
    }

    function _getRemoteEid() internal view returns (uint32) {
        if (block.chainid == 11155111) return EID_AMOY;    // On Sepolia, peer is Amoy
        if (block.chainid == 80002) return EID_SEPOLIA;    // On Amoy, peer is Sepolia
        revert("Unsupported chain");
    }
}

/**
 * @title SendTokens
 * @notice Test cross-chain token transfer
 */
contract SendTokens is Script {
    uint32 constant EID_SEPOLIA = 40161;
    uint32 constant EID_AMOY = 40267;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address localOft = vm.envAddress("LOCAL_OFT");
        uint256 amount = vm.envOr("AMOUNT", uint256(1 ether));
        address recipient = vm.envOr("RECIPIENT", deployer);

        vm.startBroadcast(deployerPrivateKey);

        VotesOFT oft = VotesOFT(localOft);
        uint32 dstEid = _getRemoteEid();

        // Build SendParam
        bytes32 to = bytes32(uint256(uint160(recipient)));
        bytes memory options = _buildOptions(200000); // 200k gas for lzReceive
        
        // Quote the fee - returns MessagingFee struct
        MessagingFee memory fee = oft.quoteSend(
            _buildSendParam(dstEid, to, amount, options),
            false // don't pay in LZ token
        );

        console2.log("Native fee required:", fee.nativeFee);
        console2.log("LZ token fee:", fee.lzTokenFee);
        console2.log("Sending amount:", amount);

        // Execute send
        oft.send{value: fee.nativeFee}(
            _buildSendParam(dstEid, to, amount, options),
            fee,  // Pass the entire MessagingFee struct
            payable(deployer) // refund address
        );

        console2.log("Tokens sent to EID:", dstEid);

        vm.stopBroadcast();
    }

    function _getRemoteEid() internal view returns (uint32) {
        if (block.chainid == 11155111) return EID_AMOY;
        if (block.chainid == 80002) return EID_SEPOLIA;
        revert("Unsupported chain");
    }

    function _buildSendParam(
        uint32 dstEid,
        bytes32 to,
        uint256 amount,
        bytes memory options
    ) internal pure returns (SendParam memory) {
        return SendParam({
            dstEid: dstEid,
            to: to,
            amountLD: amount,
            minAmountLD: (amount * 99) / 100, // 1% slippage
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });
    }

    function _buildOptions(uint128 gas) internal pure returns (bytes memory) {
        // Options type 3: lzReceive gas
        return abi.encodePacked(
            uint16(3),           // options type
            uint8(1),            // worker id (executor)
            uint16(16 + 1),      // option length
            uint8(1),            // lzReceive option type
            gas                  // gas limit
        );
    }
}

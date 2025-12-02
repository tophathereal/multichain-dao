// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SToken} from "./SToken.sol";

contract STokenBridge {
    SToken public token;                 // set after deploy
    uint256 public immutable remoteChainId;
    address public immutable relayer;

    uint256 public nonce;
    mapping(bytes32 => bool) private _processed;

    event TokensSent(
        address indexed sender,
        address indexed to,
        uint256 amount,
        uint256 nonce,
        uint256 dstChainId
    );

    event TokensReceived(
        address indexed to,
        uint256 amount,
        uint256 nonce,
        uint256 srcChainId
    );

    constructor(uint256 remoteChainId_, address relayer_) {
        require(remoteChainId_ != block.chainid, "remote == local");
        require(relayer_ != address(0), "relayer zero");
        remoteChainId = remoteChainId_;
        relayer = relayer_;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "not relayer");
        _;
    }

    /// One‑time wiring of the token after both are deployed.
    function setToken(address token_) external {
        require(address(token) == address(0), "token already set");
        require(token_ != address(0), "token zero");
        token = SToken(token_);
    }

    /// User sends tokens from *this* chain to the remote chain.
    /// User must have approved this bridge for `amount` STK.
    function sendToRemote(address to, uint256 amount) external {
        require(address(token) != address(0), "token not set");
        require(to != address(0), "to zero");
        require(amount > 0, "amount 0");

        // Burn on this chain via ERC20Bridgeable; this contract
        // must be `tokenBridge_` in SToken's constructor.
        token.crosschainBurn(msg.sender, amount);

        uint256 n = ++nonce;
        emit TokensSent(msg.sender, to, amount, n, remoteChainId);
    }

    /// Relayer mints tokens on this chain based on a remote TokensSent event.
    function mintFromRemote(
        address to,
        uint256 amount,
        uint256 nonce_,
        uint256 srcChainId
    ) external onlyRelayer {
        require(address(token) != address(0), "token not set");
        require(srcChainId == remoteChainId, "wrong src chain");
        require(to != address(0), "to zero");
        require(amount > 0, "amount 0");

        bytes32 id = keccak256(abi.encode(to, amount, nonce_, srcChainId));
        require(!_processed[id], "already processed");
        _processed[id] = true;

        token.crosschainMint(to, amount);

        emit TokensReceived(to, amount, nonce_, srcChainId);
    }
}

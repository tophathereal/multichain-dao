// abis.js

/**
 * Contract ABIs for relayer
 */
module.exports = {
    SourceBridge: [
        "event TokensLocked(address indexed from, uint256 amount, uint64 indexed destinationChainId, uint256 timestamp)",
        "function relayUnlock(bytes32 burnTxHash, address to, uint256 amount) external"
    ],

    LocalBridge: [
        "event TokensUnlocked(bytes32 indexed burnTxHash, address indexed to, uint256 amount)",
        "function relayLock(bytes32 txHash, address from, uint256 amount, uint256 sourceChainTimestamp, bytes calldata signature) external"
    ],

    ERC20VotesToken: [
        "function balanceOf(address account) view returns (uint256)",
        "function totalSupply() view returns (uint256)"
    ],

    WrappedERC20Votes: [
        "function balanceOf(address account) view returns (uint256)",
        "function totalSupply() view returns (uint256)"
    ]
};


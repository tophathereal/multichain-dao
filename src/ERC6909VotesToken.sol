// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC6909/ERC6909.sol";
import "@openzeppelin/contracts/governance/utils/Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC6909VotesToken
 * @dev Non-transferable ERC6909 token with:
 *      - ID 0: Voting power (timestamp-based, delegatable)
 *      - ID 1: Proposer permission token (non-voting)
 * Only owner can mint/burn both IDs. All transfers disabled (soulbound).
 */
contract ERC6909VotesToken is ERC6909, Votes, Ownable {
    
    uint256 public constant VOTING_TOKEN_ID = 0;
    uint256 public constant PROPOSER_TOKEN_ID = 1;

    // Token metadata
    mapping(uint256 => string) private _names;
    mapping(uint256 => string) private _symbols;
    mapping(uint256 => uint8) private _decimalsMap;

    error ERC6909VotesToken__TransfersDisabled();

    constructor(string memory votingName, string memory proposerName) 
        EIP712(votingName, "1")
        Ownable(msg.sender)
    {
        // ID 0: Voting token
        _names[VOTING_TOKEN_ID] = votingName;
        _symbols[VOTING_TOKEN_ID] = "VOTE";
        _decimalsMap[VOTING_TOKEN_ID] = 18;

        // ID 1: Proposer token
        _names[PROPOSER_TOKEN_ID] = proposerName;
        _symbols[PROPOSER_TOKEN_ID] = "PROP";
        _decimalsMap[PROPOSER_TOKEN_ID] = 0;
    }

    /**
     * @dev Returns the name for a given token ID
     */
    function name(uint256 id) public view virtual returns (string memory) {
        return _names[id];
    }

    /**
     * @dev Returns the symbol for a given token ID
     */
    function symbol(uint256 id) public view virtual returns (string memory) {
        return _symbols[id];
    }

    /**
     * @dev Returns decimals for a given token ID
     */
    function decimals(uint256 id) public view virtual returns (uint8) {
        return _decimalsMap[id];
    }

    /**
     * @dev Clock mode is timestamp-based for governance compatibility.
     */
    function clock() public view virtual override returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @dev Machine-readable clock mode description.
     */
    function CLOCK_MODE() public pure virtual override returns (string memory) {
        return "mode=timestamp";
    }

    /**
     * @dev Returns voting units (only ID 0 counts for voting power).
     */
    function _getVotingUnits(address account) internal view virtual override returns (uint256) {
        return balanceOf(account, VOTING_TOKEN_ID);
    }

    /**
     * @dev Mint voting tokens (ID 0) - owner only
     */
    function mintVoting(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, VOTING_TOKEN_ID, amount);
    }

    /**
     * @dev Burn voting tokens (ID 0) - owner only
     */
    function burnVoting(address from, uint256 amount) public virtual onlyOwner {
        _burn(from, VOTING_TOKEN_ID, amount);
    }

    /**
     * @dev Mint proposer token (ID 1) - owner only
     */
    function mintProposer(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, PROPOSER_TOKEN_ID, amount);
    }

    /**
     * @dev Burn proposer token (ID 1) - owner only
     */
    function burnProposer(address from, uint256 amount) public virtual onlyOwner {
        _burn(from, PROPOSER_TOKEN_ID, amount);
    }

    /**
     * @dev Grant proposer permission (convenience function, mints 1 token)
     */
    function grantProposer(address to) external onlyOwner {
        _mint(to, PROPOSER_TOKEN_ID, 1);
    }

    /**
     * @dev Revoke proposer permission (convenience function)
     */
    function revokeProposer(address from) external onlyOwner {
        uint256 balance = balanceOf(from, PROPOSER_TOKEN_ID);
        if (balance > 0) {
            _burn(from, PROPOSER_TOKEN_ID, balance);
        }
    }

    /**
     * @dev Check if address can propose
     */
    function canPropose(address account) public view returns (bool) {
        return balanceOf(account, PROPOSER_TOKEN_ID) > 0;
    }

    /**
     * @dev Override transfer to disable all transfers
     */
    function transfer(address, uint256, uint256) 
        public 
        virtual 
        override
        returns (bool) 
    {
        revert ERC6909VotesToken__TransfersDisabled();
    }

    /**
     * @dev Override transferFrom to disable all transfers
     */
    function transferFrom(address, address, uint256, uint256) 
        public 
        virtual 
        override
        returns (bool) 
    {
        revert ERC6909VotesToken__TransfersDisabled();
    }

    /**
     * @dev Override _update to intercept mint/burn and update voting checkpoints.
     */
    function _update(address from, address to, uint256 id, uint256 amount) 
        internal 
        virtual 
        override 
    {
        // Enforce non-transferability at internal level
        if (from != address(0) && to != address(0)) {
            revert ERC6909VotesToken__TransfersDisabled();
        }
        
        // Call parent to perform balance updates
        super._update(from, to, id, amount);
        
        // Update voting units ONLY for token ID 0
        if (id == VOTING_TOKEN_ID) {
            _transferVotingUnits(from, to, amount);
        }
    }

    /**
     * @dev Override nonces to resolve inheritance.
     */
    function nonces(address owner) 
        public 
        view 
        virtual 
        override(Nonces)
        returns (uint256) 
    {
        return super.nonces(owner);
    }
}

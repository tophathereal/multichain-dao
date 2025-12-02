# Multi-Chain Governance

Cross-chain DAO governance system using LayerZero V2 for token bridging and multi-token voting.

**Live**: [https://multi-chain-governance.pages.dev/](https://multi-chain-governance.pages.dev/)

**Sepolia VotesOFT**: 0x6Eca90d3e7452a777427DA16a62c2c7f0ff7FaA1

**Sepolia NSToken**: 0xfaaa7C76620a9C57dB5c089cFa957e00b678CE9D

**Sepolia Governor**: 0xaBb8388a0Ef1779c396e586d23E12c4B6Cf84678

**Amoy VotesOFT**: 0xCBb1f643565c1d7ea076Ee0937Cf2E999Ffc6b9D

## Architecture

### System Overview

```
┌─────────────────────────────┐         ┌─────────────────────────────┐
│      SEPOLIA (Governance)   │         │       AMOY (Source)         │
│                             │         │                             │
│  ┌──────────────────────┐   │         │  ┌──────────────────────┐   │
│  │   MultiTokenGovernor │   │         │  │                      │   │
│  │   (DAO Proposals)    │   │         │  │                      │   │
│  └──────┬───────────────┘   │         │  │                      │   │
│         │ Aggregates votes  │         │  │                      │   │
│         ├──────────┬─────┐  │         │  │                      │   │
│  ┌──────▼──────┐ ┌─▼──────┐ │         │  │                      │   │
│  │  NSToken OR │ │VotesOFT│ │◄────────┼──┤     VotesOFT         │   │
│  │ ERC6909Token│ │(OFT)   │ │ LayerZero  │     (OFT)            │   │
│  │  (ERC-20 or │ │+ Votes │ │◄────────┼──┤                      │   │
│  │   ERC-6909) │ └────────┘ │         │  └──────────────────────┘   │
│  │  + Votes    │            │         │                             │
│  └─────────────┘            │         │                             │
│                             │         │                             │
│  EID: 40161                 │         │  EID: 40267                 │
└─────────────────────────────┘         └─────────────────────────────┘
```

### Key Components

- **Sepolia**: Governance hub with voting aggregation from multiple tokens
- **Amoy**: Token source chain for cross-chain participation
- **LayerZero V2**: Trustless message passing for token transfers between chains

## Smart Contract Logic

### VotesOFT (Cross-Chain Token)

**Purpose**: ERC-20 token with voting power that can bridge between chains

**Key Features**:
- Inherits LayerZero OFT (Omnichain Fungible Token)
- Implements ERC-5805 voting with checkpoints
- Supports delegation and vote tracking
- Initial supply: 1,000,000 tokens

**Core Functions**:
```
// Voting
delegate(address delegatee)                    // Delegate voting power
getVotes(address account) → uint256           // Current voting power
getPastVotes(address, uint256) → uint256      // Historical voting power

// Cross-chain
send(SendParam, MessagingFee, address)        // Bridge tokens to other chain
quoteSend(SendParam, bool) → MessagingFee     // Get bridging cost
setPeer(uint32 eid, bytes32 peer)            // Configure remote chain
```

**Deployment**: Both Sepolia and Amoy

### NSToken (Native Governance Token)

**Purpose**: Standard ERC-20 token with voting capabilities on governance chain

**Key Features**:
- ERC-20 with ERC-5805 voting extensions
- Fixed supply: 1,000,000 tokens
- Delegation and checkpoint support
- No cross-chain functionality

**Deployment**: Sepolia only (default option)

### ERC6909VotesToken (Advanced Multi-Token Governance)

**Purpose**: ERC-6909 multi-token contract with separate voting and proposer tokens

**Key Features**:
- **Token ID 0 (Voting)**: Delegatable voting power with timestamp-based checkpoints
- **Token ID 1 (Proposer)**: Non-voting permission token for proposal creation
- Soulbound (non-transferable) - tokens cannot be transferred between accounts
- Owner-controlled minting/burning for both token types
- Full ERC-5805 voting compatibility

**Core Functions**:
```
// Voting token (ID 0)
mintVoting(address to, uint256 amount)        // Mint voting tokens
burnVoting(address from, uint256 amount)      // Burn voting tokens
delegate(address delegatee)                   // Delegate voting power
getVotes(address account) → uint256          // Current voting power

// Proposer token (ID 1)
grantProposer(address to)                     // Grant proposal permission
revokeProposer(address from)                  // Revoke proposal permission
canPropose(address account) → bool            // Check proposer status

// Metadata per token ID
name(uint256 id) → string
symbol(uint256 id) → string
decimals(uint256 id) → uint8
```

**Use Cases**:
- Separate voting rights from proposal rights
- Non-transferable governance tokens (soul-bound)
- Reputation-based governance systems
- Role-based DAO participation

**Deployment**: Sepolia only (optional alternative to NSToken)

### MultiTokenGovernor (DAO Contract)

**Purpose**: OpenZeppelin Governor that aggregates votes from multiple token contracts

**Governance Parameters**:
- Voting delay: 1 block
- Voting period: 50,400 blocks (~7 days)
- Quorum: 4% of total supply
- Proposal threshold: 0 tokens

**Vote Aggregation**:
```
// Constructor accepts array of vote tokens
constructor(IVotes[] memory _voteTokens)

// Sums voting power across all registered tokens
getVotes(address account, uint256 timepoint) → uint256
```

**Proposal Lifecycle**:
```
1. propose() → Create proposal with targets, values, calldatas
2. castVote() → Vote: 0=Against, 1=For, 2=Abstain
3. execute() → Execute if quorum met and majority votes For
```

**Deployment**: Sepolia only

## Deployment

### Smart Contracts

#### Option 1: Deploy with NSToken (default)
```
# 1. Deploy to both chains
export PRIVATE_KEY="your_private_key"
make deploy-sepolia    # Deploys: VotesOFT, NSToken, MultiTokenGovernor
make deploy-amoy       # Deploys: VotesOFT only

# 2. Configure cross-chain peers
export LOCAL_OFT="0xSepoliaVotesOFTAddress"
export REMOTE_OFT="0xAmoyVotesOFTAddress"
make set-peers-sepolia

export LOCAL_OFT="0xAmoyVotesOFTAddress"
export REMOTE_OFT="0xSepoliaVotesOFTAddress"
make set-peers-amoy
```

#### Option 2: Deploy with ERC6909VotesToken
```
# 1. Deploy to Sepolia with ERC6909
export PRIVATE_KEY="your_private_key"
export USE_ERC6909=true
export ERC6909_INITIAL_SUPPLY=1000000000000000000000000  # 1 million tokens
export GRANT_PROPOSER=true  # Grant proposer permission to deployer
make deploy-sepolia    # Deploys: VotesOFT, ERC6909VotesToken, MultiTokenGovernor

# 2. Deploy to Amoy (same as before)
make deploy-amoy       # Deploys: VotesOFT only

# 3. Configure cross-chain peers (same as before)
export LOCAL_OFT="0xSepoliaVotesOFTAddress"
export REMOTE_OFT="0xAmoyVotesOFTAddress"
make set-peers-sepolia

export LOCAL_OFT="0xAmoyVotesOFTAddress"
export REMOTE_OFT="0xSepoliaVotesOFTAddress"
make set-peers-amoy
```

### Frontend

```
# 1. Deploy to Cloudflare Pages
make frontend-deploy
```

## Usage

```
# Build contracts
make build

# Run tests
make test

# Deploy with NSToken (default)
make deploy-all

# Deploy with ERC6909VotesToken
USE_ERC6909=true make deploy-sepolia

# Deploy frontend only
make frontend-deploy

# Local development
make frontend-dev
```

## Technical Stack

- **Solidity**: 0.8.27
- **Framework**: Foundry
- **Standards**: ERC-20, ERC-6909, ERC-5805 (Votes), LayerZero V2 OFT
- **Governance**: OpenZeppelin Governor
- **Frontend**: Cloudflare Pages + MetaMask
- **Networks**: Sepolia (testnet), Amoy (testnet)

## Project Structure

```
├── src/
│   ├── VotesOFT.sol           # Cross-chain voting token
│   ├── NSToken.sol            # Native governance token (ERC-20)
│   ├── ERC6909VotesToken.sol  # Multi-token governance (ERC-6909)
│   └── MyGovernor.sol         # Multi-token DAO
├── script/
│   └── Deploy.s.sol           # Deployment scripts
├── frontend/
│   ├── index.html             # Web interface
│   ├── config.json            # Contract addresses
│   └── *.json                 # ABIs (auto-generated)
├── Makefile                   # Build automation
└── foundry.toml               # Foundry config
```

## Token Comparison

| Feature | NSToken | ERC6909VotesToken |
|---------|---------|-------------------|
| Standard | ERC-20 | ERC-6909 |
| Transferable | ✅ Yes | ❌ No (Soulbound) |
| Voting Power | ✅ Yes | ✅ Yes (ID 0) |
| Proposer Rights | Based on balance | ✅ Separate token (ID 1) |
| Multi-Token | ❌ No | ✅ Yes (2 IDs) |
| Use Case | Standard DAO | Reputation/Role-based DAO |
| Deployment | Default | Set `USE_ERC6909=true` |

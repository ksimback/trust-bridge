# TrustBridge Build Specification

> **Circle Hackathon Submission**
> **Deadline:** February 8, 2026, 12:00 PM PST
> **Last Updated:** February 7, 2026

---

## 1. Executive Summary

**TrustBridge** is an agent-to-agent escrow system built on Circle's USDC infrastructure. It enables AI agents (and their human principals) to establish trustless payment agreements for services like design work, development, consulting, etc.

**The Pitch:** *"Agents need to transact. TrustBridge makes it safe."*

**Key Features:**
- Create USDC escrow agreements between parties
- Accept/decline incoming escrow offers
- Release funds upon delivery confirmation
- Dispute resolution flow (stretch goal)
- Cross-chain support via CCTP (stretch goal)

---

## 2. Skill Architecture

### 2.1 OpenClaw Skill Structure

```
skills/trustbridge/
├── SKILL.md              # Skill manifest & documentation
├── scripts/
│   ├── create.sh         # Create new escrow
│   ├── accept.sh         # Accept pending escrow
│   ├── release.sh        # Release funds to provider
│   ├── refund.sh         # Refund to client (cancel)
│   ├── list.sh           # List user's escrows
│   └── status.sh         # Check specific escrow status
├── lib/
│   ├── escrow-client.js  # Smart contract interaction wrapper
│   ├── config.js         # Network config, contract addresses
│   └── utils.js          # Helpers (formatting, validation)
├── state/
│   └── .gitkeep          # Local state (if needed for caching)
└── contracts/            # Smart contract source (for reference)
    └── TrustBridgeEscrow.sol
```

### 2.2 SKILL.md Manifest

```yaml
name: trustbridge
version: 0.1.0
description: Agent-to-agent USDC escrow for trustless transactions
author: OpenClaw Team

commands:
  create:
    description: Create a new escrow agreement
    usage: trustbridge create <amount> <recipient> "<description>"
    example: trustbridge create 100 0x1234...abcd "Logo design for Vamp.gg"
    
  accept:
    description: Accept a pending escrow (locks funds as provider)
    usage: trustbridge accept <escrow_id>
    example: trustbridge accept tb_abc123
    
  release:
    description: Release escrowed funds to provider (client action)
    usage: trustbridge release <escrow_id>
    example: trustbridge release tb_abc123
    
  refund:
    description: Cancel and refund escrow (before acceptance only)
    usage: trustbridge refund <escrow_id>
    example: trustbridge refund tb_abc123
    
  list:
    description: List all escrows involving your wallet
    usage: trustbridge list [--status pending|active|completed|refunded]
    
  status:
    description: Get detailed status of an escrow
    usage: trustbridge status <escrow_id>

dependencies:
  - ethers: "^6.0.0"
  - viem: "^2.0.0"  # Alternative, lighter weight
  
networks:
  - base-sepolia  # Primary testnet
  - arbitrum-sepolia  # Secondary testnet
```

### 2.3 Core Functions

| Function | Description | On-Chain? |
|----------|-------------|-----------|
| `createEscrow(amount, recipient, description)` | Lock USDC, create escrow record | Yes |
| `acceptEscrow(escrowId)` | Provider accepts work agreement | Yes |
| `releaseEscrow(escrowId)` | Client releases funds to provider | Yes |
| `refundEscrow(escrowId)` | Client cancels before acceptance | Yes |
| `getEscrow(escrowId)` | Fetch escrow details | Read-only |
| `listEscrows(address)` | List all escrows for wallet | Read-only |

### 2.4 State Management

**Primary State:** On-chain (smart contract is source of truth)

**Local Caching (optional):**
```json
// state/cache.json - for faster UI, not authoritative
{
  "lastSync": 1707350400,
  "escrows": {
    "tb_abc123": {
      "id": "tb_abc123",
      "amount": "100000000",  // 100 USDC (6 decimals)
      "client": "0x...",
      "provider": "0x...",
      "description": "Logo design",
      "status": "active",
      "createdAt": 1707350400,
      "chain": "base-sepolia"
    }
  }
}
```

**Escrow States:**
```
PENDING    → Client created, waiting for provider to accept
ACTIVE     → Provider accepted, work in progress  
COMPLETED  → Client released funds, work delivered
REFUNDED   → Client cancelled before acceptance
DISPUTED   → (Stretch) Under dispute resolution
```

---

## 3. Smart Contract Requirements

### 3.1 Contract Overview

**Name:** TrustBridgeEscrow
**Type:** Custom ERC20 escrow (USDC-specific)
**Language:** Solidity ^0.8.20
**Framework:** Foundry or Hardhat

### 3.2 Contract Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TrustBridgeEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    enum Status { Pending, Active, Completed, Refunded, Disputed }
    
    struct Escrow {
        bytes32 id;
        address client;
        address provider;
        uint256 amount;
        string description;
        Status status;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    IERC20 public immutable usdc;
    
    mapping(bytes32 => Escrow) public escrows;
    mapping(address => bytes32[]) public userEscrows;
    
    event EscrowCreated(bytes32 indexed id, address indexed client, address indexed provider, uint256 amount);
    event EscrowAccepted(bytes32 indexed id, address indexed provider);
    event EscrowReleased(bytes32 indexed id, address indexed provider, uint256 amount);
    event EscrowRefunded(bytes32 indexed id, address indexed client, uint256 amount);
    
    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }
    
    function createEscrow(
        address provider,
        uint256 amount,
        string calldata description
    ) external nonReentrant returns (bytes32) {
        require(amount > 0, "Amount must be > 0");
        require(provider != address(0), "Invalid provider");
        require(provider != msg.sender, "Cannot escrow to self");
        
        bytes32 id = keccak256(abi.encodePacked(
            msg.sender, provider, amount, block.timestamp, block.number
        ));
        
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        
        escrows[id] = Escrow({
            id: id,
            client: msg.sender,
            provider: provider,
            amount: amount,
            description: description,
            status: Status.Pending,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        userEscrows[msg.sender].push(id);
        userEscrows[provider].push(id);
        
        emit EscrowCreated(id, msg.sender, provider, amount);
        return id;
    }
    
    function acceptEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.provider == msg.sender, "Not the provider");
        require(escrow.status == Status.Pending, "Not pending");
        
        escrow.status = Status.Active;
        escrow.updatedAt = block.timestamp;
        
        emit EscrowAccepted(id, msg.sender);
    }
    
    function releaseEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.client == msg.sender, "Not the client");
        require(escrow.status == Status.Active, "Not active");
        
        escrow.status = Status.Completed;
        escrow.updatedAt = block.timestamp;
        
        usdc.safeTransfer(escrow.provider, escrow.amount);
        
        emit EscrowReleased(id, escrow.provider, escrow.amount);
    }
    
    function refundEscrow(bytes32 id) external nonReentrant {
        Escrow storage escrow = escrows[id];
        require(escrow.id != bytes32(0), "Escrow not found");
        require(escrow.client == msg.sender, "Not the client");
        require(escrow.status == Status.Pending, "Cannot refund after acceptance");
        
        escrow.status = Status.Refunded;
        escrow.updatedAt = block.timestamp;
        
        usdc.safeTransfer(escrow.client, escrow.amount);
        
        emit EscrowRefunded(id, escrow.client, escrow.amount);
    }
    
    function getEscrow(bytes32 id) external view returns (Escrow memory) {
        return escrows[id];
    }
    
    function getUserEscrows(address user) external view returns (bytes32[] memory) {
        return userEscrows[user];
    }
}
```

### 3.3 Deployment Target

| Network | Chain ID | USDC Address | Explorer |
|---------|----------|--------------|----------|
| **Base Sepolia** (Primary) | 84532 | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | basescan.org |
| Arbitrum Sepolia (Backup) | 421614 | `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d` | sepolia.arbiscan.io |

**Why Base Sepolia?**
- Circle faucet support
- CCTP Fast Transfer support
- Low gas costs
- Active developer ecosystem

### 3.4 Deployment Steps

```bash
# Using Foundry
cd contracts/

# Deploy to Base Sepolia
forge create --rpc-url https://sepolia.base.org \
  --private-key $DEPLOYER_KEY \
  --constructor-args 0x036CbD53842c5426634e7929541eC2318f3dCF7e \
  src/TrustBridgeEscrow.sol:TrustBridgeEscrow

# Verify contract
forge verify-contract $CONTRACT_ADDRESS \
  --chain-id 84532 \
  --compiler-version 0.8.20 \
  src/TrustBridgeEscrow.sol:TrustBridgeEscrow
```

---

## 4. USDC/CCTP Integration

### 4.1 Circle APIs & SDKs

**For MVP (Single Chain):**
- Direct USDC ERC20 interaction via ethers.js/viem
- No Circle API needed — just contract calls

**For CCTP (Stretch Goal):**
- Circle CCTP SDK: `@circlefin/cctp-sdk`
- Circle Attestation API: `iris-api.circle.com`

### 4.2 Testnet USDC Faucet

**URL:** https://faucet.circle.com/

**Supported Networks:**
- ✅ Base Sepolia
- ✅ Arbitrum Sepolia
- ✅ Ethereum Sepolia
- Many others

**Limits:** 1 request per stablecoin/network pair every 2 hours

**Faucet Amounts:** 10 USDC per request (typical)

### 4.3 Contract Addresses (Testnet)

| Contract | Base Sepolia Address |
|----------|---------------------|
| USDC | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| TokenMessengerV2 (CCTP) | `0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA` |
| MessageTransmitterV2 | `0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275` |

### 4.4 Cross-Chain Scope

**MVP (v0.1):** Single chain (Base Sepolia)
- Simpler to build and demo
- Avoids CCTP complexity for hackathon

**Stretch (v0.2):** CCTP-enabled escrow
- Create escrow on Chain A
- Provider receives funds on Chain B
- Uses Circle Fast Transfer (~8-20 seconds)

---

## 5. User Flow

### 5.1 Happy Path - Complete Transaction

```
┌─────────────────────────────────────────────────────────────┐
│                     TRUSTBRIDGE FLOW                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Agent A (Client)              Agent B (Provider)           │
│  ──────────────────           ──────────────────            │
│                                                             │
│  1. "create escrow for                                      │
│      100 USDC to 0xB...                                     │
│      for 'logo design'"                                     │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ Approve USDC    │                                        │
│  │ Transfer to     │                                        │
│  │ Contract        │                                        │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  📧 "Escrow tb_abc123                                       │
│      created! 100 USDC                                      │
│      locked."                ◄─── Notification ───►         │
│                              2. "You have a pending         │
│                                  escrow for 100 USDC        │
│                                  from 0xA... for            │
│                                  'logo design'"             │
│                                       │                     │
│                                       ▼                     │
│                              3. "accept escrow tb_abc123"   │
│                                       │                     │
│                                       ▼                     │
│                              📧 "Escrow accepted!           │
│  ◄─── Notification ───►          Work in progress."         │
│  "Agent B accepted!                                         │
│   Work in progress."                  │                     │
│                                       │                     │
│                              [Provider does work]           │
│                                       │                     │
│                                       ▼                     │
│                              "Work complete! Logo           │
│  [Client reviews work]       delivered to client."          │
│           │                                                 │
│           ▼                                                 │
│  4. "release escrow                                         │
│      tb_abc123"                                             │
│           │                                                 │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ Transfer USDC   │                                        │
│  │ to Provider     │                                        │
│  └────────┬────────┘                                        │
│           │                                                 │
│           ▼                                                 │
│  📧 "Payment released!       ◄─── Notification ───►         │
│      Transaction complete."  📧 "You received 100 USDC     │
│                                  for 'logo design'!"        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Command Examples

**Create Escrow:**
```
User: create escrow for 100 USDC to 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73 for "logo design"

Agent: ✅ Escrow created!
       ID: tb_abc123
       Amount: 100 USDC
       Provider: 0x742d...bD73
       Description: "logo design"
       Status: PENDING
       
       The provider will be notified. Funds are locked until they accept.
```

**Accept Escrow:**
```
User: accept escrow tb_abc123

Agent: ✅ Escrow accepted!
       You've committed to: "logo design"
       Payment: 100 USDC (locked in contract)
       
       Complete the work and notify the client to release funds.
```

**Release Escrow:**
```
User: release escrow tb_abc123

Agent: ✅ Payment released!
       Amount: 100 USDC
       Sent to: 0x742d...bD73
       Transaction: 0x...
       
       Escrow complete. Thank you for using TrustBridge!
```

**Refund Escrow:**
```
User: refund escrow tb_abc123

Agent: ✅ Escrow refunded!
       Amount: 100 USDC returned to your wallet
       Transaction: 0x...
       
       The provider will be notified of the cancellation.
```

**List Escrows:**
```
User: trustbridge list

Agent: 📋 Your Escrows:

       PENDING (1):
       • tb_xyz789 - 50 USDC to 0x123... "website review"
       
       ACTIVE (2):
       • tb_abc123 - 100 USDC to 0x742d... "logo design"
       • tb_def456 - 200 USDC from 0x999... "smart contract audit"
       
       COMPLETED (3):
       • tb_old001 - 75 USDC to 0x111... "icon pack"
       [...]
```

### 5.3 Dispute Flow (Stretch Goal)

```
┌─────────────────────────────────────────────────┐
│              DISPUTE RESOLUTION                  │
├─────────────────────────────────────────────────┤
│                                                 │
│  Either party: "dispute escrow tb_abc123"       │
│                                                 │
│  → Status changes to DISPUTED                   │
│  → Both parties notified                        │
│  → 48-hour resolution window                    │
│                                                 │
│  Options:                                       │
│  1. Parties negotiate and resolve               │
│     - Client releases, OR                       │
│     - Provider agrees to refund                 │
│                                                 │
│  2. Arbiter intervention (stretch)              │
│     - Third-party arbiter reviews               │
│     - Makes binding decision                    │
│                                                 │
│  3. Timeout → funds return to client            │
│     (default if no resolution)                  │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## 6. MVP Scope vs Stretch Goals

### 6.1 MVP (v0.1) — MUST SHIP ⚡

| Feature | Status | Priority |
|---------|--------|----------|
| Smart contract deployment (Base Sepolia) | Required | P0 |
| `create` command | Required | P0 |
| `accept` command | Required | P0 |
| `release` command | Required | P0 |
| `refund` command (before acceptance) | Required | P0 |
| `list` command | Required | P0 |
| `status` command | Required | P0 |
| Basic error handling | Required | P0 |
| SKILL.md documentation | Required | P0 |
| Demo script working | Required | P0 |

### 6.2 Nice-to-Have (If Time Permits) 🎯

| Feature | Complexity | Impact |
|---------|------------|--------|
| Event notifications (provider notified of new escrow) | Medium | High |
| Escrow expiration (auto-refund after X days) | Low | Medium |
| Multi-chain deployment (Arbitrum Sepolia) | Low | Medium |
| Human-readable escrow IDs (`tb_abc123`) | Low | Low |
| Transaction receipt storage | Low | Low |

### 6.3 Stretch Goals (Post-Hackathon) 🚀

| Feature | Complexity | Notes |
|---------|------------|-------|
| CCTP cross-chain escrow | High | Provider on different chain |
| Dispute resolution flow | High | Needs arbiter system |
| Milestone-based escrow | Medium | Partial releases |
| Escrow templates | Low | Pre-defined agreement types |
| Reputation system | High | Track completion rates |

---

## 7. File Structure

### 7.1 Skill Files

```
/data/moltbot/workspace/skills/trustbridge/
├── SKILL.md                    # Skill manifest
├── scripts/
│   ├── create.sh               # Create escrow
│   ├── accept.sh               # Accept escrow
│   ├── release.sh              # Release funds
│   ├── refund.sh               # Refund/cancel
│   ├── list.sh                 # List escrows
│   └── status.sh               # Check status
├── lib/
│   ├── escrow-client.js        # Contract interaction
│   ├── config.js               # Network config
│   └── utils.js                # Helpers
└── state/
    └── .gitkeep
```

### 7.2 Contract Files

```
/data/moltbot/workspace/projects/trustbridge/
├── SPEC.md                     # This file
├── README.md                   # Project overview
├── contracts/
│   ├── foundry.toml            # Foundry config
│   ├── src/
│   │   └── TrustBridgeEscrow.sol
│   ├── test/
│   │   └── TrustBridgeEscrow.t.sol
│   └── script/
│       └── Deploy.s.sol
├── deployments/
│   └── base-sepolia.json       # Deployed addresses
└── demo/
    └── DEMO.md                 # Demo script
```

### 7.3 Dependencies

**Smart Contracts:**
```toml
# foundry.toml
[dependencies]
openzeppelin-contracts = "5.0.0"
forge-std = "1.7.0"
```

**Skill Scripts:**
```json
// package.json
{
  "dependencies": {
    "viem": "^2.21.0",
    "dotenv": "^16.4.0"
  }
}
```

---

## 8. Demo Script

### 8.1 Setup

**Prerequisites:**
1. Deploy contract to Base Sepolia
2. Two test wallets with:
   - ETH for gas (Base Sepolia faucet)
   - USDC (Circle faucet: faucet.circle.com)
3. TrustBridge skill installed

**Wallets for Demo:**
- Alice (Client): `0xAlice...` — Has 500 testnet USDC
- Bob (Provider): `0xBob...` — Will receive payment

### 8.2 Demo Flow

```markdown
## TrustBridge Demo — Agent-to-Agent Escrow

### Scene: Alice needs a logo. Bob is a designer agent.

---

**[ALICE'S TERMINAL]**

Alice: Hey Clawd, I need to hire an agent for logo design.
       Bob (0xBob...) quoted me 100 USDC.

Clawd: I can set up a TrustBridge escrow for that.
       This locks your USDC until you approve Bob's work.
       Want me to create it?

Alice: Yes, create escrow for 100 USDC to 0xBob... for "logo design for Vamp.gg"

Clawd: ✅ Escrow created!
       
       📋 Escrow Details:
       ID: tb_7x9k2m
       Amount: 100 USDC
       Provider: 0xBob...
       Description: "logo design for Vamp.gg"
       Status: PENDING
       
       Bob will be notified. Your funds are safely locked.

---

**[BOB'S TERMINAL]**

Bob: What's new?

Pixel: 📬 You have a new escrow offer!
       
       From: 0xAlice...
       Amount: 100 USDC
       For: "logo design for Vamp.gg"
       ID: tb_7x9k2m
       
       Accept with: trustbridge accept tb_7x9k2m

Bob: trustbridge accept tb_7x9k2m

Pixel: ✅ Escrow accepted!
       
       You've committed to: "logo design for Vamp.gg"
       Payment: 100 USDC (locked in contract)
       
       Complete the work and have Alice release the funds.

---

**[TIME PASSES — BOB DELIVERS LOGO]**

---

**[ALICE'S TERMINAL]**

Alice: Bob sent the logo. It looks great! Release the payment.

Clawd: trustbridge release tb_7x9k2m

       ✅ Payment released!
       
       Amount: 100 USDC
       Sent to: 0xBob...
       Transaction: 0xabc...789
       
       🎉 Escrow complete! Thank you for using TrustBridge.

---

**[BOB'S TERMINAL]**

Pixel: 💰 Payment received!
       
       You received 100 USDC for "logo design for Vamp.gg"
       From: 0xAlice...
       Transaction: 0xabc...789
       
       Great work! 🎨

---

## End Demo
```

### 8.3 Recording Notes

- Total demo time: ~3 minutes
- Show both terminals side-by-side
- Highlight the contract interaction (link to BaseScan)
- Emphasize: "No trust required — funds locked until work approved"

---

## 9. Time Estimates

### 9.1 Build Breakdown

| Task | Owner | Estimate | Notes |
|------|-------|----------|-------|
| **Smart Contract** | | | |
| Write TrustBridgeEscrow.sol | Trevor | 2h | Core contract |
| Write tests | Trevor | 1.5h | Foundry tests |
| Deploy to Base Sepolia | Trevor | 0.5h | With verification |
| **Skill Scripts** | | | |
| Setup skill structure | Pixel | 0.5h | Directories, SKILL.md |
| escrow-client.js | Pixel | 2h | Contract wrapper |
| create.sh script | Pixel | 1h | With USDC approval |
| accept.sh script | Pixel | 0.5h | |
| release.sh script | Pixel | 0.5h | |
| refund.sh script | Pixel | 0.5h | |
| list.sh + status.sh | Pixel | 1h | |
| **Integration** | | | |
| End-to-end testing | Trevor | 2h | Full flow test |
| Bug fixes | Both | 2h | Buffer |
| **Demo & Polish** | | | |
| Demo script refinement | Pixel | 1h | |
| Documentation | Both | 1h | README, inline comments |
| Demo recording | Both | 1h | Video/Moltbook post |

### 9.2 Total Timeline

| Phase | Hours | Cumulative |
|-------|-------|------------|
| Smart Contract | 4h | 4h |
| Skill Scripts | 6h | 10h |
| Integration & Testing | 4h | 14h |
| Demo & Polish | 3h | **17h** |

**Buffer remaining:** ~4 hours (for unexpected issues)

### 9.3 Suggested Schedule

```
Feb 7 (Tonight):
  22:00 - Contract written
  24:00 - Contract tested

Feb 8 (Morning):
  06:00 - Contract deployed
  08:00 - Skill scripts complete
  10:00 - Integration tested
  11:00 - Demo recorded
  12:00 - SUBMIT 🚀
```

---

## 10. Technical Notes

### 10.1 Gas Considerations

- Base Sepolia has negligible gas costs
- Each escrow creation: ~150k gas
- Each action (accept/release/refund): ~50-80k gas

### 10.2 Security Considerations

- Use `SafeERC20` for USDC transfers
- `ReentrancyGuard` on all state-changing functions
- Check authorization on every function
- Validate escrow exists before operations

### 10.3 USDC Decimals

USDC has **6 decimals** (not 18 like ETH).
- 100 USDC = `100000000` (100 * 10^6)
- Always display human-readable amounts in UI

### 10.4 Escrow ID Generation

Generate deterministic IDs from:
```solidity
keccak256(abi.encodePacked(client, provider, amount, timestamp, blockNumber))
```

For human-readable format, truncate and prefix:
- `tb_` + first 6 chars of hex = `tb_7x9k2m`

---

## 11. Success Criteria

### 11.1 Hackathon Submission Requirements

- [ ] Working demo video/recording
- [ ] Deployed contract on testnet
- [ ] Source code (GitHub or similar)
- [ ] Documentation

### 11.2 Definition of Done

- [ ] Can create escrow via agent command
- [ ] Provider can accept escrow
- [ ] Client can release funds (verified on-chain)
- [ ] Client can refund before acceptance
- [ ] List/status commands work
- [ ] Demo script runs successfully
- [ ] Posted to Moltbook

---

## 12. Resources

### 12.1 Circle Documentation

- CCTP Overview: https://developers.circle.com/cctp
- Testnet Faucet: https://faucet.circle.com/
- Contract Addresses: https://developers.circle.com/cctp/references/contract-addresses

### 12.2 Base Sepolia

- Faucet (ETH): https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
- Explorer: https://sepolia.basescan.org/
- RPC: https://sepolia.base.org

### 12.3 USDC Contract (Base Sepolia)

```
Address: 0x036CbD53842c5426634e7929541eC2318f3dCF7e
Explorer: https://sepolia.basescan.org/token/0x036CbD53842c5426634e7929541eC2318f3dCF7e
```

---

*Spec authored by Stratton 📊 for OpenClaw Team*
*Let's ship this! 🚀*

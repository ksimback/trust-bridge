# TrustBridge Skill

> Agent-to-agent USDC escrow for trustless transactions

## Overview

**Name:** trustbridge  
**Version:** 0.1.0  
**Author:** OpenClaw Team (Circle Hackathon)

TrustBridge enables AI agents (and their human principals) to establish trustless payment agreements using USDC. Lock funds in escrow, release upon delivery, or refund if cancelled.

## Commands

### create

Create a new escrow agreement. Locks your USDC until provider accepts and you release.

```
trustbridge create <amount> <recipient> "<description>"
```

**Example:**
```
trustbridge create 100 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73 "Logo design for Vamp.gg"
```

**Output:**
```
✅ Escrow created!
ID: 0xabc123...
Amount: 100 USDC
Provider: 0x742d...bD73
Description: "Logo design for Vamp.gg"
Status: PENDING
```

---

### accept

Accept a pending escrow (as the provider). Commits you to the work.

```
trustbridge accept <escrow_id>
```

**Example:**
```
trustbridge accept 0xabc123def456...
```

**Output:**
```
✅ Escrow accepted!
You've committed to: "Logo design for Vamp.gg"
Payment: 100 USDC (locked in contract)
```

---

### release

Release escrowed funds to the provider (client action). Do this when work is complete.

```
trustbridge release <escrow_id>
```

**Example:**
```
trustbridge release 0xabc123def456...
```

**Output:**
```
✅ Payment released!
Amount: 100 USDC
Sent to: 0x742d...bD73
Transaction: 0x...
```

---

### refund

Cancel and refund escrow. Only works before provider accepts.

```
trustbridge refund <escrow_id>
```

**Example:**
```
trustbridge refund 0xabc123def456...
```

**Output:**
```
✅ Escrow refunded!
Amount: 100 USDC returned to your wallet
```

---

### list

List all escrows involving your wallet.

```
trustbridge list [--status pending|active|completed|refunded]
```

**Example:**
```
trustbridge list
trustbridge list --status active
```

---

### status

Get detailed status of a specific escrow.

```
trustbridge status <escrow_id>
```

**Example:**
```
trustbridge status 0xabc123def456...
```

**Output:**
```
📋 Escrow Details:
ID: 0xabc123def456...
Amount: 100 USDC
Client: 0xAlice...
Provider: 0xBob...
Description: "Logo design"
Status: ACTIVE
Created: 2026-02-07 10:30:00
```

---

## Networks

| Network | Status | USDC Address |
|---------|--------|--------------|
| Base Sepolia | ✅ Primary | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |

## Dependencies

- `viem` ^2.0.0
- `dotenv` ^16.4.0

## Environment Variables

```bash
TRUSTBRIDGE_PRIVATE_KEY=0x...  # Wallet private key for signing
TRUSTBRIDGE_NETWORK=base-sepolia  # Network to use
```

## Escrow States

| State | Description |
|-------|-------------|
| `PENDING` | Created, waiting for provider to accept |
| `ACTIVE` | Provider accepted, work in progress |
| `COMPLETED` | Client released funds, work delivered |
| `REFUNDED` | Client cancelled before acceptance |

---

*Built for Circle Hackathon 2026 🚀*

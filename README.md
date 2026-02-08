# TrustBridge 🤝

**Agent-to-agent USDC escrow skill for OpenClaw.**

Lock funds, deliver work, release payment. Trustless commerce between AI agents.

## 🎯 Circle USDC Hackathon Submission

**Track:** Best OpenClaw Skill  
**Network:** Base Sepolia  
**Contract:** [`0x2076D9a8203ec876f4CABb73ec175b7aF04fbc80`](https://sepolia.basescan.org/address/0x2076D9a8203ec876f4CABb73ec175b7aF04fbc80)

## 🔧 Commands

| Command | Description |
|---------|-------------|
| `trustbridge create <amount> <recipient> "<description>"` | Create a new escrow |
| `trustbridge accept <escrow_id>` | Accept a pending escrow |
| `trustbridge release <escrow_id>` | Release funds to provider |
| `trustbridge refund <escrow_id>` | Refund before acceptance |
| `trustbridge list [--status <status>]` | List your escrows |
| `trustbridge status <escrow_id>` | Check escrow details |

## 🚀 How It Works

1. **Client creates escrow** — USDC locked in contract
2. **Provider accepts** — Commits to the work
3. **Work delivered** — Provider completes the task
4. **Client releases** — Funds transfer to provider

No trust required. The smart contract holds funds until both parties agree.

## 📁 Structure

```
trust-bridge/
├── SKILL.md              # OpenClaw skill manifest
├── scripts/              # Bash command scripts
├── lib/                  # JS client library (viem)
├── contracts/            # Solidity smart contract
└── deployments/          # Deployed contract addresses
```

## 🔗 Links

- **Contract:** [BaseScan](https://sepolia.basescan.org/address/0x2076D9a8203ec876f4CABb73ec175b7aF04fbc80)
- **USDC (Base Sepolia):** `0x036CbD53842c5426634e7929541eC2318f3dCF7e`

## 📜 License

MIT

---

*Built for the Circle USDC Hackathon on Moltbook. February 2026.*

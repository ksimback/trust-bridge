#!/bin/bash
# TrustBridge: Release Escrow
# Usage: release.sh <escrow_id>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check args
if [ $# -lt 1 ]; then
    echo "Usage: release.sh <escrow_id>"
    echo "Example: release.sh 0xabc123..."
    exit 1
fi

ESCROW_ID="$1"

# Get escrow details first
ESCROW=$(node "$LIB_DIR/escrow-client.js" status "$ESCROW_ID" 2>&1)
AMOUNT=$(echo "$ESCROW" | jq -r '.amount // "?"')
PROVIDER=$(echo "$ESCROW" | jq -r '.provider // "?"')

# Release escrow
RESULT=$(node "$LIB_DIR/escrow-client.js" release "$ESCROW_ID" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to release escrow"
    echo "$RESULT"
    exit 1
fi

TX_HASH=$(echo "$RESULT" | jq -r '.txHash // empty')
EXPLORER=$(echo "$RESULT" | jq -r '.explorer // empty')

echo "✅ Payment released!"
echo ""
echo "Amount: $AMOUNT USDC"
echo "Sent to: ${PROVIDER:0:6}...${PROVIDER: -4}"
echo ""
echo "Transaction: $TX_HASH"
echo "Explorer: $EXPLORER"
echo ""
echo "🎉 Escrow complete! Thank you for using TrustBridge."

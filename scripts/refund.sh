#!/bin/bash
# TrustBridge: Refund Escrow
# Usage: refund.sh <escrow_id>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check args
if [ $# -lt 1 ]; then
    echo "Usage: refund.sh <escrow_id>"
    echo "Example: refund.sh 0xabc123..."
    exit 1
fi

ESCROW_ID="$1"

# Get escrow details first
ESCROW=$(node "$LIB_DIR/escrow-client.js" status "$ESCROW_ID" 2>&1)
AMOUNT=$(echo "$ESCROW" | jq -r '.amount // "?"')

# Refund escrow
RESULT=$(node "$LIB_DIR/escrow-client.js" refund "$ESCROW_ID" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to refund escrow"
    echo "$RESULT"
    exit 1
fi

TX_HASH=$(echo "$RESULT" | jq -r '.txHash // empty')
EXPLORER=$(echo "$RESULT" | jq -r '.explorer // empty')

echo "✅ Escrow refunded!"
echo ""
echo "Amount: $AMOUNT USDC returned to your wallet"
echo ""
echo "Transaction: $TX_HASH"
echo "Explorer: $EXPLORER"
echo ""
echo "The provider will be notified of the cancellation."

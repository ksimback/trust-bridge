#!/bin/bash
# TrustBridge: Accept Escrow
# Usage: accept.sh <escrow_id>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check args
if [ $# -lt 1 ]; then
    echo "Usage: accept.sh <escrow_id>"
    echo "Example: accept.sh 0xabc123..."
    exit 1
fi

ESCROW_ID="$1"

# Get escrow details first
ESCROW=$(node "$LIB_DIR/escrow-client.js" status "$ESCROW_ID" 2>&1)
DESCRIPTION=$(echo "$ESCROW" | jq -r '.description // "Unknown"')
AMOUNT=$(echo "$ESCROW" | jq -r '.amount // "?"')

# Accept escrow
RESULT=$(node "$LIB_DIR/escrow-client.js" accept "$ESCROW_ID" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to accept escrow"
    echo "$RESULT"
    exit 1
fi

TX_HASH=$(echo "$RESULT" | jq -r '.txHash // empty')
EXPLORER=$(echo "$RESULT" | jq -r '.explorer // empty')

echo "✅ Escrow accepted!"
echo ""
echo "You've committed to: \"$DESCRIPTION\""
echo "Payment: $AMOUNT USDC (locked in contract)"
echo ""
echo "Transaction: $TX_HASH"
echo "Explorer: $EXPLORER"
echo ""
echo "Complete the work and have the client release the funds."

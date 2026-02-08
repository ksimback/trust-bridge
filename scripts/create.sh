#!/bin/bash
# TrustBridge: Create Escrow
# Usage: create.sh <amount> <recipient> "<description>"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check args
if [ $# -lt 3 ]; then
    echo "Usage: create.sh <amount> <recipient> <description>"
    echo "Example: create.sh 100 0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73 \"Logo design\""
    exit 1
fi

AMOUNT="$1"
RECIPIENT="$2"
shift 2
DESCRIPTION="$*"

# Call escrow client
RESULT=$(node "$LIB_DIR/escrow-client.js" create "$AMOUNT" "$RECIPIENT" "$DESCRIPTION" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to create escrow"
    echo "$RESULT"
    exit 1
fi

# Parse result
ESCROW_ID=$(echo "$RESULT" | jq -r '.escrowId // empty')
TX_HASH=$(echo "$RESULT" | jq -r '.txHash // empty')
EXPLORER=$(echo "$RESULT" | jq -r '.explorer // empty')

# Format output
echo "✅ Escrow created!"
echo ""
echo "📋 Escrow Details:"
echo "ID: ${ESCROW_ID:-unknown}"
echo "Amount: $AMOUNT USDC"
echo "Provider: ${RECIPIENT:0:6}...${RECIPIENT: -4}"
echo "Description: \"$DESCRIPTION\""
echo "Status: PENDING"
echo ""
echo "Transaction: $TX_HASH"
echo "Explorer: $EXPLORER"
echo ""
echo "The provider will be notified. Funds are locked until they accept."

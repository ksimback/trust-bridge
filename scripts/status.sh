#!/bin/bash
# TrustBridge: Get Escrow Status
# Usage: status.sh <escrow_id>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check args
if [ $# -lt 1 ]; then
    echo "Usage: status.sh <escrow_id>"
    echo "Example: status.sh 0xabc123..."
    exit 1
fi

ESCROW_ID="$1"

# Get escrow details
RESULT=$(node "$LIB_DIR/escrow-client.js" status "$ESCROW_ID" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to get escrow status"
    echo "$RESULT"
    exit 1
fi

# Parse fields
ID=$(echo "$RESULT" | jq -r '.id // "?"')
CLIENT=$(echo "$RESULT" | jq -r '.client // "?"')
PROVIDER=$(echo "$RESULT" | jq -r '.provider // "?"')
AMOUNT=$(echo "$RESULT" | jq -r '.amount // "?"')
DESCRIPTION=$(echo "$RESULT" | jq -r '.description // "?"')
STATUS=$(echo "$RESULT" | jq -r '.status // "?"')
CREATED=$(echo "$RESULT" | jq -r '.createdAt // "?"')
UPDATED=$(echo "$RESULT" | jq -r '.updatedAt // "?"')

# Status emoji
case $STATUS in
    PENDING) EMOJI="⏳" ;;
    ACTIVE) EMOJI="🔄" ;;
    COMPLETED) EMOJI="✅" ;;
    REFUNDED) EMOJI="↩️" ;;
    *) EMOJI="❓" ;;
esac

echo "📋 Escrow Details:"
echo ""
echo "ID: $ID"
echo "Amount: $AMOUNT USDC"
echo "Client: ${CLIENT:0:6}...${CLIENT: -4}"
echo "Provider: ${PROVIDER:0:6}...${PROVIDER: -4}"
echo "Description: \"$DESCRIPTION\""
echo "Status: $EMOJI $STATUS"
echo ""
echo "Created: $CREATED"
echo "Updated: $UPDATED"

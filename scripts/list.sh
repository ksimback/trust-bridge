#!/bin/bash
# TrustBridge: List Escrows
# Usage: list.sh [--status pending|active|completed|refunded] [address]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

STATUS_FILTER=""
ADDRESS=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --status)
            STATUS_FILTER="$2"
            shift 2
            ;;
        *)
            ADDRESS="$1"
            shift
            ;;
    esac
done

# Get all escrows
RESULT=$(node "$LIB_DIR/escrow-client.js" list "$ADDRESS" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ Failed to list escrows"
    echo "$RESULT"
    exit 1
fi

# Check if empty
COUNT=$(echo "$RESULT" | jq 'length')
if [ "$COUNT" = "0" ]; then
    echo "📋 No escrows found."
    exit 0
fi

echo "📋 Your Escrows:"
echo ""

# Group by status
for status in PENDING ACTIVE COMPLETED REFUNDED; do
    # Skip if filter is set and doesn't match
    if [ -n "$STATUS_FILTER" ] && [ "${STATUS_FILTER^^}" != "$status" ]; then
        continue
    fi
    
    # Filter escrows by status
    FILTERED=$(echo "$RESULT" | jq -r --arg s "$status" '.[] | select(.status == $s)')
    
    if [ -n "$FILTERED" ]; then
        STATUS_COUNT=$(echo "$RESULT" | jq --arg s "$status" '[.[] | select(.status == $s)] | length')
        echo "$status ($STATUS_COUNT):"
        
        echo "$RESULT" | jq -r --arg s "$status" '.[] | select(.status == $s) | "• \(.id[0:10])... - \(.amount) USDC | \(.description[0:30])"'
        echo ""
    fi
done

#!/bin/bash

echo "Testing Uniswap V2 Invariants with Medusa"
echo "=========================================="

# Check if medusa is installed
if ! command -v medusa &> /dev/null; then
    echo "Error: Medusa is not installed. Please install it first:"
    echo "go install github.com/crytic/medusa/cmd/medusa@latest"
    exit 1
fi

# Run medusa fuzzing
echo "Starting Medusa fuzzing campaign..."
echo "This will test the following invariants:"
echo "- Constant Product Formula (K invariant)"
echo "- Reserves Match Balances"
echo "- Minimum Liquidity Locked"
echo "- Total Supply Consistency"
echo "- No Overflow in Reserves"
echo "- Price Accumulator Increases"
echo "- Liquidity Tokens Conservation"
echo "- K Last Consistency"
echo "- No Token Loss"
echo "- Swap Amount Bounds"
echo ""

medusa fuzz --config medusa.json

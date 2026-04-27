#!/bin/bash
# Regenerate docs/ADDRESSES.md from deployments/7119.json + 7120.json.
# Run after every coordinated mainnet + testnet deploy so the docs stay
# in sync with the JSON source-of-truth automatically.

set -euo pipefail

cd "$(dirname "$0")/.."

OUT=docs/ADDRESSES.md
MAINNET=deployments/7119.json
TESTNET=deployments/7120.json

emit_table() {
  local file="$1"
  local label="$2"
  local chain_id="$3"
  echo ""
  echo "## $label (chain $chain_id)"
  echo ""
  echo "| Contract | Address | Deployed at | Tx |"
  echo "|---|---|---|---|"
  if command -v jq >/dev/null 2>&1 && [ -f "$file" ]; then
    jq -r 'to_entries
      | map(select(.key | startswith("_") | not))
      | .[]
      | "| \(.key) | `\(.value.address // "0x...")` | \(.value.deployed_at // "TBD") | `\(.value.tx // "0x...")` |"' "$file"
  else
    for c in WSRX Multicall3 SentrixSafe TokenFactory; do
      echo "| $c | \`0x...\` | TBD | \`0x...\` |"
    done
  fi
}

{
  echo "# Canonical Addresses"
  echo ""
  echo "> **Auto-generated from deployments/7119.json + deployments/7120.json by script/GenerateAddressDocs.sh.** Do not edit by hand."
  emit_table "$MAINNET" "Sentrix Mainnet" 7119
  emit_table "$TESTNET" "Sentrix Testnet" 7120
  echo ""
  echo "## Versioning"
  echo ""
  echo "Each release tag (\`vX.Y.Z\`) corresponds to a coordinated deploy. See \`RELEASES.md\` for the release log."
} > "$OUT"

echo "Wrote $OUT"

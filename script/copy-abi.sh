#!/bin/bash
# Copy compiled ABI artifacts from forge build output into deployments/abi/.
# Run after `forge build` and after every deploy.

set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p deployments/abi

for c in WSRX Multicall3 SentrixSafe TokenFactory; do
  src="out/${c}.sol/${c}.json"
  dst="deployments/abi/${c}.json"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    echo "  $src -> $dst"
  else
    echo "  (skip $c: $src not found — run 'forge build' first)"
  fi
done

# FactoryToken is deployed by TokenFactory; ABI lives in the same artifact tree.
ft_src="out/TokenFactory.sol/FactoryToken.json"
if [ -f "$ft_src" ]; then
  cp "$ft_src" "deployments/abi/FactoryToken.json"
  echo "  $ft_src -> deployments/abi/FactoryToken.json"
fi

echo "done."

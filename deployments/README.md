# Deployments

Per-network deployed-address registry. Source-of-truth for SDK consumers, integrators, and tooling.

## Files

| File | Network |
|---|---|
| `7119.json` | Sentrix Mainnet |
| `7120.json` | Sentrix Testnet |
| `abi/*.json` | Compiled ABI artifacts (one per contract) |

## Format

Each per-network JSON file has this shape:

```json
{
  "_chainId": 7119,
  "_network": "Sentrix Mainnet",
  "WSRX": {
    "address": "0x...",
    "tx": "0x...",
    "block": 692500,
    "deployer": "0x...",
    "deployed_at": "2026-04-28"
  },
  "Multicall3": { ... },
  "SentrixSafe": { ... },
  "TokenFactory": { ... }
}
```

Keys starting with `_` are metadata (not contracts). Each contract entry contains:

| Field | Type | Meaning |
|---|---|---|
| `address` | `0x` + 40 hex | Deployed contract address |
| `tx` | `0x` + 64 hex | Deploy transaction hash |
| `block` | `u64` | Block height at which the deploy was mined |
| `deployer` | `0x` + 40 hex | EOA that signed the deploy tx |
| `deployed_at` | `YYYY-MM-DD` | Calendar date of the deploy |

## Reading from JS / TS

```ts
import mainnet from "./deployments/7119.json";
import testnet from "./deployments/7120.json";

const wsrx = (chainId: number) => (chainId === 7119 ? mainnet : testnet).WSRX.address;
```

## Updating after a deploy

1. After `forge script Deploy*.s.sol --broadcast`, capture the address from the broadcast log
2. Edit the per-network JSON file
3. Add the contract entry per the format above
4. Commit on the same release branch as the deploy tag

See `docs/DEPLOYMENT.md` for the full release flow.

## ABI files

`abi/<Contract>.json` files are the **compiled artifact** outputs from `forge build`. Refresh them after every deploy by running:

```bash
./script/copy-abi.sh
```

This script copies `out/<Contract>.sol/<Contract>.json` to `deployments/abi/<Contract>.json`. The ABI is part of the public surface — SDK consumers depend on it.

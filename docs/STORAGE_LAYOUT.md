# Storage Layout

Storage-slot layout per contract. Used for future upgrade planning (if a contract gains a proxy) and for verifying that ABI changes don't shift storage.

## How to regenerate

```bash
make storage
```

This runs `forge inspect <Contract> storage-layout` for each canonical contract and writes the JSON output to `docs/storage/<Contract>.json`. Run after any storage-layout change.

## Files

| File | Source | Purpose |
|---|---|---|
| `docs/storage/WSRX.json` | `forge inspect WSRX storage-layout` | WETH9-style: `totalSupply`, `balanceOf`, `allowance` |
| `docs/storage/Multicall3.json` | `forge inspect Multicall3 storage-layout` | Stateless — empty layout |
| `docs/storage/SentrixSafe.json` | `forge inspect SentrixSafe storage-layout` | `owners[]`, `isOwner`, `threshold`, `nonce` |
| `docs/storage/TokenFactory.json` | `forge inspect TokenFactory storage-layout` | `deployedTokens` mapping |

## Why this matters

Solidity storage layout is determined by declaration order. **Reordering or inserting fields changes slot assignments** — a critical concern if a contract is ever wrapped in a proxy. Even though the canonical set is immutable today (no proxies), capturing the layout per-release means a future upgrade can write a storage migration safely.

## Snapshot policy

The committed JSON files in `docs/storage/` are the snapshot at release time. Diffs between releases reveal:

- Added field at the end of the struct → safe (does not shift existing slots)
- Inserted field in the middle → DANGEROUS (shifts later slots)
- Removed field → DANGEROUS (slots reused)
- Reordered fields → DANGEROUS (all shifted)

CI does not auto-fail on diffs (storage adds are normal between releases). Reviewer must visually check the diff during PR review.

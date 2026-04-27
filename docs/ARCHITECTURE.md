# Canonical Contracts — Architecture

Four contracts make up the canonical set deployed by Sentrix Labs. They are intentionally minimal, dependency-free where possible, and immutable once deployed.

## Contracts at a glance

| Contract | Purpose | License |
|---|---|---|
| `WSRX` | Wraps native SRX into an ERC-20 (18 decimals) so EVM dApps can hold it as a token | BUSL-1.1 |
| `Multicall3` | Aggregates multiple contract reads/writes into one tx | MIT (verbatim mirror of `mds1/multicall`) |
| `SentrixSafe` | Minimal multi-sig (Gnosis Safe v1.4.1-derived) for treasury management | BUSL-1.1 |
| `TokenFactory` | One-call ERC-20 deploy for builders who don't want to write Solidity | BUSL-1.1 |

## How they fit together

```
                  ┌──────────────────────────┐
                  │  Native SRX (8-decimal)  │
                  │  Sentrix Chain ledger    │
                  └─────────────┬────────────┘
                                │   wrapped at 1 SRX = 10^10 wei
                                ▼
   ┌───────────┐   wraps     ┌─────────┐   ERC-20    ┌──────────────┐
   │  user     │────────────▶│  WSRX   │────────────▶│  any DeFi    │
   └─────┬─────┘             └─────────┘             │  protocol    │
         │                                           └──────────────┘
         │                   ┌──────────────┐
         ├──reads──────────▶ │  Multicall3  │  batches view + write calls
         │                   └──────────────┘
         │
         │                   ┌──────────────┐
         ├──treasury ops──▶  │  SentrixSafe │  N-of-M signatures
         │                   └──────────────┘
         │
         │                   ┌──────────────┐
         └──deploy ERC-20─▶  │ TokenFactory │  emits new FactoryToken
                             └──────────────┘
```

## SRX 8-decimal ↔ WSRX 18-decimal conversion

Sentrix's native ledger uses **8 decimals** (`1 SRX = 100,000,000 sentri`). The EVM exposes balances as **18-decimal wei** via a `10^10` multiplier at the EVM-database adapter boundary. So:

| Layer | 1 SRX in this layer's units |
|---|---|
| Native ledger (`Account.balance`) | `100_000_000` sentri |
| EVM (`eth_getBalance`, `msg.value`) | `1_000_000_000_000_000_000` wei |
| WSRX (`WSRX.balanceOf`) | `1_000_000_000_000_000_000` (1:1 with msg.value) |

When a user calls `WSRX.deposit{value: 1 ether}()`:
- `msg.value` arrives as `10^18` wei (already converted by the adapter from `10^8` sentri the native account had)
- `WSRX.balanceOf[user] += 10^18`
- On `WSRX.withdraw(10^18)`, the inverse: WSRX is burned, native SRX (`10^8` sentri) is sent back

dApps never see `sentri` — they treat WSRX as a standard ERC-20 with 18 decimals.

## Deploy order

1. **WSRX** — no dependencies; deploy first
2. **Multicall3** — no dependencies; deploy in parallel
3. **SentrixSafe** — needs the owner-set + threshold from operator
4. **TokenFactory** — no dependencies; deploys `FactoryToken` instances on demand

All four can be deployed in a single run — no cross-contract initialisation required.

## Upgrade policy

There is **no upgrade proxy.** A bug = redeploy `vN+1`, advise migration in `RELEASES.md`. Audit before mainnet. See `SECURITY.md`.

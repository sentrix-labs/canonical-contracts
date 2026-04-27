# FAQ

## Why is WSRX 18 decimals when SRX is 8?

Sentrix's native ledger uses 8-decimal accounting (`1 SRX = 100,000,000 sentri`) — BTC-style. The EVM expects 18-decimal wei semantics. Conversion happens at the EVM database adapter boundary: `1 sentri = 10^10 wei`. By the time `msg.value` arrives in a Solidity function, it's already 18-decimal wei, so WSRX can mint 1:1 against `msg.value` and stay ERC-20-compatible.

In practice:

| Layer | 1 SRX |
|---|---|
| Native ledger | `100_000_000` sentri |
| EVM (`msg.value`, `eth_getBalance`) | `1_000_000_000_000_000_000` wei |
| WSRX (`balanceOf`) | `1_000_000_000_000_000_000` |

dApps treat WSRX as a standard 18-decimal ERC-20 — they never need to know about `sentri`.

## How does the conversion `sentri ↔ wei` work?

It's a constant `10^10` multiplier maintained by the EVM database adapter (`crates/sentrix-evm/src/database.rs::SentrixEvmDb`). When the EVM reads `Account.balance` (a `u64` in sentri), it multiplies by `10^10` to produce a `U256` wei value. When the EVM commits a balance change, it divides by `10^10` to write back to sentri. Truncation cannot happen in normal flow because both directions of the conversion are exact integer multiples — but if a contract attempts to credit a fractional sentri (e.g., 1 wei on the EVM side, less than `10^10`), the AccountDB write rounds down and the dust is silently absorbed.

The user-facing implication: avoid working with sub-sentri amounts (< `10^10` wei) in EVM transfers; below that boundary, value is lost.

## What's the difference between native TokenOp and EVM ERC-20?

| Aspect | Native TokenOp | EVM ERC-20 |
|---|---|---|
| Where it lives | Sentrix native dispatch (`POST /tokens/deploy`, `TokenOp::Deploy`) | EVM contract storage (revm 37) |
| How you deploy | Native tx with `data = TokenOp JSON` | `eth_sendRawTransaction` with EVM bytecode |
| How you query | REST `/tokens/{contract}/...` | `eth_call` with `balanceOf` etc. |
| Address scheme | Derived from `tx.txid` (Sentrix-specific) | EVM CREATE/CREATE2 |
| Compatible with MetaMask? | No — needs Sentrix-aware client | Yes — standard ERC-20 |
| Gas / fee | Flat fee 0.0001 SRX | Standard EVM gas |
| Use case | Sentrix-native UX (lower fee, faster integration into Sentrix scan) | dApp ecosystem compat (DEX, lending, NFT marketplace) |

If you're building a dApp targeting the broader EVM ecosystem, deploy ERC-20 via EVM. If you're building a Sentrix-native experience, use TokenOp. WSRX bridges the two — wrap native SRX into an ERC-20 that works in EVM dApps.

## How do I add Sentrix to MetaMask?

1. Open MetaMask → "Add network" → "Add manually"
2. Paste:
   - Network name: `Sentrix Mainnet`
   - New RPC URL: `https://rpc.sentrixchain.com`
   - Chain ID: `7119`
   - Currency symbol: `SRX`
   - Block explorer URL: `https://scan.sentrixchain.com`
3. Save

For testnet, use chain ID `7120` and `https://testnet-rpc.sentrixchain.com`.

A Chainlist.org entry has been submitted (PR #8266 upstream); once accepted, MetaMask users can add Sentrix via Chainlist with one click.

## Why no upgrade proxy?

Canonical contracts are deliberately immutable. Reasoning:

- Eliminates upgrade-key trust assumption (no admin can rug)
- Smaller attack surface (no proxy slot collisions, no fallback handler tricks)
- If a contract has a bug, deploy `vN+1` and migrate — the canonical set is small enough that a coordinated cutover is feasible

If a future contract genuinely needs upgradability (e.g., complex governance logic), it'll go through the canonical-contracts review process with explicit upgrade-path documentation.

## How is WSRX different from WETH?

Functionally identical — WSRX is a near-verbatim WETH9 fork, just renamed and with 18-decimal accounting verified to match the EVM-side wei view of native SRX. The interface is the same: `deposit()`, `withdraw(uint256)`, plus standard ERC-20.

## Can I use Multicall3 at the canonical address `0xcA11bde05977b3631167028862bE2a173976CA11`?

Not yet. Sentrix's first deploy uses plain CREATE so the address is whatever the deployer's nonce produces. To replicate the canonical address you need the standard Create2 deployer (`0x4e59b44847b379578588920cA78FbF26c0B4956C`) with the canonical salt — that's a follow-up deploy operation (planned but not in v1.0.0). For now, look up the actual deployed address in `deployments/7119.json` or `docs/ADDRESSES.md`.

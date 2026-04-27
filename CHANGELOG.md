# Changelog

All notable changes to Sentrix canonical contracts are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Tag pattern `vX.Y.Z`. Each release tag corresponds to a coordinated deploy to mainnet (chain 7119) + testnet (chain 7120).

---

## [Unreleased]

Initial canonical-contracts repo scaffold. No on-chain deploys yet.

### Added

- `contracts/WSRX.sol` — Wrapped SRX (ERC-20, 18-decimal, native bridge)
- `contracts/Multicall3.sol` — Standard Multicall3 (read/write batch)
- `contracts/SentrixSafe.sol` — Minimal multi-sig (Gnosis Safe v1.4.1-derived)
- `contracts/TokenFactory.sol` — ERC-20 deployer
- `script/Deploy*.s.sol` — Foundry deploy scripts (per-contract)
- `test/*.t.sol` — Foundry tests (per-contract)
- `deployments/{7119,7120}.json` — empty templates pending first deploy
- `foundry.toml`, CI workflow, README, LICENSE

---

## [1.0.0] — TBD

(filled in on first coordinated deploy to mainnet + testnet)

### Deployed

- `WSRX` @ `0x...` (mainnet 7119)
- `WSRX` @ `0x...` (testnet 7120)
- `Multicall3` @ `0x...` (both networks; canonical Create2 address `0xcA11bde05977b3631167028862bE2a173976CA11` if via Create2 deployer)
- `SentrixSafe` @ `0x...`
- `TokenFactory` @ `0x...`

# Changelog

All notable changes to Sentrix canonical contracts are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Tag pattern `vX.Y.Z`. Each release tag corresponds to a coordinated deploy to mainnet (chain 7119) + testnet (chain 7120).

---

## [Unreleased]

### Documentation

- **`docs/ADDRESSES.md`** — added "SentrixSafe ownership" section documenting the 2026-04-28 migration history and the final 1-of-1 state.
- **`script/TransferOwnership.s.sol`** — rewritten to document the completed migration with `AUTHORITY` / `SAFE_MAINNET` / `SAFE_TESTNET` constants. Read-only print of final state.
- **`README.md`** — SentrixSafe row links to the ownership section in `docs/ADDRESSES.md`.

### Governance

- **SentrixSafe ownership migration FINAL (2026-04-28)** — both Safes now 1-of-1 with the Sentrix Labs authority signer `0xa25236925bc10954e0519731cc7ba97f4bb5714b` (threshold=1). Bootstrap deployer retired from Safe ownership.

  | Step | Chain | Tx | Block |
  |---|---|---|---|
  | addOwner(authority, 1) | testnet 7120 | `0xb70a83eb416e…` | 881639 |
  | addOwner(authority, 1) | mainnet 7119 | `0xd17400c35f07…` | 755821 |
  | removeOwner(deployer, 1) | testnet 7120 | `0xb0c69e89252c…` | 884599 |
  | removeOwner(deployer, 1) | mainnet 7119 | `0x8e9ca8b4cbe0…` | 757829 |

---

## [1.0.0] — 2026-04-27 — Initial deploy to Sentrix mainnet (7119) + testnet (7120)

> **All four canonical contracts deployed.** Single coordinated deploy session by `0x5acb04058fc4dfa258f29ce318282377cac176fd` (bootstrap deployer EOA, retired from Safe ownership 2026-04-28). All addresses immutable.

### Deployed — chain 7119 (Sentrix mainnet)

| Contract | Address | Block | Deploy tx |
|---|---|---|---|
| WSRX | `0x4693b113e523A196d9579333c4ab8358e2656553` | 716787 | `0xc5b5016338ba2de65ebb631374724bcc33db63b9a570e77d455d896b40f103fb` |
| Multicall3 | `0xFd4b34b5763f54a580a0d9f7997A2A993ef9ceE9` | 717078 | `0x64633e100f952d845970590fda32786118cf5e6b29b56c281d8d1e4b8e889f0a` |
| TokenFactory | `0xc753199b723649ab92c6db8A45F158921CFDEe49` | 717392 | `0xfda6219d60219e223d049158bca734d77e475c0b6b0c02074beeba0c701be112` |
| SentrixSafe | `0x6272dC0C842F05542f9fF7B5443E93C0642a3b26` | 717618 | `0xc67fb31dd135051732a41530e26897fb7c10eaec1fc6cb9334b596073758cb0f` |

### Deployed — chain 7120 (Sentrix testnet)

| Contract | Address | Block | Deploy tx |
|---|---|---|---|
| WSRX | `0x85d5E7694AF31C2Edd0a7e66b7c6c92C59fF949A` | 723183 | `0xfcfd2e0c1b3b4e61a2166a35cbb780d8370e9d1d6c67f7137aeb66c52260e8b3` |
| Multicall3 | `0x7900826De548425c6BE56caEbD4760AB0155Cd54` | 723191 | `0x1f8d6749f7ffdcbbaabfad21167d5133593944be6c59025c69c3f6543cb7f6c2` |
| TokenFactory | `0x7A2992af0d4979aDD076347666023d66d29276Fc` | 723195 | `0xe68e5553af080a97181e09279782873f884477759656e51c03f522c94cb9da47` |
| SentrixSafe | `0xc9D7a61D7C2F428F6A055916488041fD00532110` | 723511 | `0x514863050498a545fa627d696aa82cdd2558bc35470418d7f83af8f1c0a12176` |

### Initial scaffold (pre-deploy work, all merged)

- `contracts/WSRX.sol` — Wrapped SRX (ERC-20, 18-decimal, native bridge)
- `contracts/Multicall3.sol` — Standard Multicall3 (read/write batch)
- `contracts/SentrixSafe.sol` — Minimal multi-sig (Gnosis Safe v1.4.1-derived; array-based owners with `addOwner` / `removeOwner` / `execTransaction`)
- `contracts/TokenFactory.sol` — ERC-20 deployer (open factory, anyone may call)
- `script/Deploy*.s.sol` — Foundry deploy scripts (per-contract) + `CheckDeployment.s.sol` smoke test
- `test/*.t.sol` — unit + fuzz + invariant + integration tests
- `deployments/{7119,7120}.json` — populated with deployed addresses
- `deployments/abi/*.json` — ABI exports refreshed via `script/copy-abi.sh`
- `docs/ADDRESSES.md` — auto-generated from deployments JSON via `script/GenerateAddressDocs.sh`
- CI: `forge build + test + snapshot`, slither static analysis, CodeQL — all green

### Notes

- WSRX, Multicall3, and TokenFactory have **no owner role** (immutable). Only SentrixSafe has owner-set governance via `execTransaction`.
- SentrixSafe deployed initially as a **1-of-1 multisig owned by the bootstrap deployer**. Migrated to 1-of-1 with authority signer post-deploy (see Unreleased §Governance above).

Multicall3 deployed at a non-canonical address — the cross-chain canonical `0xcA11bde05977b3631167028862bE2a173976CA11` (via Create2 deployer) is **not** in use here. Initial Sentrix deploy used plain CREATE for v1; future revisions may add a Create2 path if cross-chain tooling demands it.

# Canonical Addresses

> **Auto-generated from deployments/7119.json + deployments/7120.json by script/GenerateAddressDocs.sh.** Do not edit by hand.

## Sentrix Mainnet (chain 7119)

| Contract | Address | Deployed at | Tx |
|---|---|---|---|
| WSRX | `0x4693b113e523A196d9579333c4ab8358e2656553` | 2026-04-27 | `0xc5b5016338ba2de65ebb631374724bcc33db63b9a570e77d455d896b40f103fb` |
| Multicall3 | `0xFd4b34b5763f54a580a0d9f7997A2A993ef9ceE9` | 2026-04-27 | `0x64633e100f952d845970590fda32786118cf5e6b29b56c281d8d1e4b8e889f0a` |
| TokenFactory | `0xc753199b723649ab92c6db8A45F158921CFDEe49` | 2026-04-27 | `0xfda6219d60219e223d049158bca734d77e475c0b6b0c02074beeba0c701be112` |
| SentrixSafe | `0x6272dC0C842F05542f9fF7B5443E93C0642a3b26` | 2026-04-27 | `0xc67fb31dd135051732a41530e26897fb7c10eaec1fc6cb9334b596073758cb0f` |

## Sentrix Testnet (chain 7120)

| Contract | Address | Deployed at | Tx |
|---|---|---|---|
| WSRX | `0x85d5E7694AF31C2Edd0a7e66b7c6c92C59fF949A` | 2026-04-27 | `0xfcfd2e0c1b3b4e61a2166a35cbb780d8370e9d1d6c67f7137aeb66c52260e8b3` |
| Multicall3 | `0x7900826De548425c6BE56caEbD4760AB0155Cd54` | 2026-04-27 | `0x1f8d6749f7ffdcbbaabfad21167d5133593944be6c59025c69c3f6543cb7f6c2` |
| TokenFactory | `0x7A2992af0d4979aDD076347666023d66d29276Fc` | 2026-04-27 | `0xe68e5553af080a97181e09279782873f884477759656e51c03f522c94cb9da47` |
| SentrixSafe | `0xc9D7a61D7C2F428F6A055916488041fD00532110` | 2026-04-27 | `0x514863050498a545fa627d696aa82cdd2558bc35470418d7f83af8f1c0a12176` |

## SentrixSafe ownership

Both Safes (mainnet `0x6272dC0C842F05542f9fF7B5443E93C0642a3b26` and testnet `0xc9D7a61D7C2F428F6A055916488041fD00532110`) are configured as **1-of-1 multisigs** with `threshold=1`. The sole owner is the Sentrix Labs authority signer:

```
authority = 0xa25236925bc10954e0519731cc7ba97f4bb5714b
```

Migration history (2026-04-28):

| Step | Chain | Action | Tx | Block |
|---|---|---|---|---|
| 1 | testnet (7120) | `addOwner(authority, 1)` | `0xb70a83eb416e2323aa8cc422d72fc89bd9a6f6e4338ce2b6bc8560a711d0c70f` | 881639 |
| 2 | mainnet (7119) | `addOwner(authority, 1)` | `0xd17400c35f0716db7410384fd728ed3b02185bf861880aad7b44326ba7690b19` | 755821 |
| 3 | testnet (7120) | `removeOwner(deployer, 1)` | `0xb0c69e89252c4e00b920600b2211f3857c07da0aa7f5c6719cc3dc8c42b6d728` | 884599 |
| 4 | mainnet (7119) | `removeOwner(deployer, 1)` | `0x8e9ca8b4cbe0bac8332de225045b83059b3a05ea2748d58d61218c7598d1d6e0` | 757829 |

The bootstrap deployer (`0x5acb04058fc4dfa258f29ce318282377cac176fd`) is no longer a Safe owner on either chain. All future Safe-governed actions (further `addOwner` / `removeOwner` / `execTransaction` calls to canonical contracts that ever gain owner roles) require the authority signature.

Verification (any node, post PR #389):

```bash
cast call 0x6272dC0C842F05542f9fF7B5443E93C0642a3b26 "getOwners()(address[])" --rpc-url https://rpc.sentrixchain.com
cast call 0x6272dC0C842F05542f9fF7B5443E93C0642a3b26 "getThreshold()(uint256)" --rpc-url https://rpc.sentrixchain.com
```

Expected: `[0xa25236925bc10954e0519731cc7ba97f4bb5714b]` and `1`.

## Versioning

Each release tag (`vX.Y.Z`) corresponds to a coordinated deploy. See `RELEASES.md` for the release log.

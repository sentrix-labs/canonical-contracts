# Releases

Each release tag (`v1.0.0`, `v1.1.0`, …) records a coordinated deploy to **mainnet (7119) + testnet (7120)**. Per release, capture: contract name, deployed address, deploy-tx hash, deployer address, block height.

## How a release works

1. Compile + test on a feature branch (`forge test --rpc-url sentrix_testnet`)
2. Open PR → CI green → merge to `main`
3. Tag the release: `git tag v1.0.0 && git push --tags`
4. Run deploy scripts (testnet first, mainnet second, in same session):

   ```bash
   forge script script/DeployWSRX.s.sol:DeployWSRX \
     --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY
   forge script script/DeployWSRX.s.sol:DeployWSRX \
     --rpc-url sentrix_mainnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY
   ```

5. Update `deployments/7119.json` + `deployments/7120.json` with the new addresses
6. Append a row to the table below

---

## Release log

| Tag | Date | Network | Contract | Address | Deploy tx | Deployer | Block |
|-----|------|---------|----------|---------|-----------|----------|-------|
| v1.0.0 | 2026-04-27 | mainnet 7119 | WSRX | `0x4693b113e523A196d9579333c4ab8358e2656553` | `0xc5b5016338ba…` | `0x5acb04058fc4…` | 716787 |
| v1.0.0 | 2026-04-27 | mainnet 7119 | Multicall3 | `0xFd4b34b5763f54a580a0d9f7997A2A993ef9ceE9` | `0x64633e100f95…` | `0x5acb04058fc4…` | 717078 |
| v1.0.0 | 2026-04-27 | mainnet 7119 | TokenFactory | `0xc753199b723649ab92c6db8A45F158921CFDEe49` | `0xfda6219d6021…` | `0x5acb04058fc4…` | 717392 |
| v1.0.0 | 2026-04-27 | mainnet 7119 | SentrixSafe | `0x6272dC0C842F05542f9fF7B5443E93C0642a3b26` | `0xc67fb31dd135…` | `0x5acb04058fc4…` | 717618 |
| v1.0.0 | 2026-04-27 | testnet 7120 | WSRX | `0x85d5E7694AF31C2Edd0a7e66b7c6c92C59fF949A` | `0xfcfd2e0c1b3b…` | `0x5acb04058fc4…` | 723183 |
| v1.0.0 | 2026-04-27 | testnet 7120 | Multicall3 | `0x7900826De548425c6BE56caEbD4760AB0155Cd54` | `0x1f8d6749f7ff…` | `0x5acb04058fc4…` | 723191 |
| v1.0.0 | 2026-04-27 | testnet 7120 | TokenFactory | `0x7A2992af0d4979aDD076347666023d66d29276Fc` | `0xe68e5553af08…` | `0x5acb04058fc4…` | 723195 |
| v1.0.0 | 2026-04-27 | testnet 7120 | SentrixSafe | `0xc9D7a61D7C2F428F6A055916488041fD00532110` | `0x514863050498…` | `0x5acb04058fc4…` | 723511 |

## Post-deploy governance moves

| Date | Chain | Action | Tx | Block |
|---|---|---|---|---|
| 2026-04-28 | testnet 7120 | SentrixSafe `addOwner(authority, 1)` | `0xb70a83eb416e…` | 881639 |
| 2026-04-28 | mainnet 7119 | SentrixSafe `addOwner(authority, 1)` | `0xd17400c35f07…` | 755821 |
| 2026-04-28 | testnet 7120 | SentrixSafe `removeOwner(deployer, 1)` | `0xb0c69e89252c…` | 884599 |
| 2026-04-28 | mainnet 7119 | SentrixSafe `removeOwner(deployer, 1)` | `0x8e9ca8b4cbe0…` | 757829 |

Final SentrixSafe state (both chains): **1-of-1 with authority signer `0xa25236925bc10954e0519731cc7ba97f4bb5714b`**, threshold=1, nonce=2. Bootstrap deployer retired from Safe ownership.

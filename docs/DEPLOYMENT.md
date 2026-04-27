# Deployment Runbook

Step-by-step for a fresh `vX.Y.Z` deploy.

## 1. Prepare environment

```bash
cp .env.example .env
$EDITOR .env
# Fill in DEPLOYER_PRIVATE_KEY (no 0x prefix tolerated by foundry; both forms work)
```

`.env` is gitignored. Rotate the deployer key after each release if you suspect exposure.

## 2. Fund the deployer wallet

The deployer EOA needs SRX on **both** networks before any deploy. Per memory `secret-faucets/deployer/wallet.txt` for the exact deployer address.

Send from the founder wallet (operator action, off-repo):
- Testnet (chain 7120): ~0.5 SRX → enough for 4 deploys at low gas
- Mainnet (chain 7119): ~0.5 SRX → same

Both nets can use the same deployer EOA (Sentrix uses the same address scheme on testnet + mainnet).

## 3. Install dependencies

```bash
forge install foundry-rs/forge-std
# Optional: forge install OpenZeppelin/openzeppelin-contracts (none of the canonical contracts import OZ today, but the remapping is wired so future contracts can use it)
```

## 4. Build + test

```bash
forge build --sizes
forge test -vvv
forge fmt --check
```

Must all pass before deploy.

## 5. Deploy testnet first

```bash
source .env

forge script script/DeployWSRX.s.sol:DeployWSRX \
  --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY

forge script script/DeployMulticall3.s.sol:DeployMulticall3 \
  --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Safe needs SAFE_OWNERS + SAFE_THRESHOLD env vars set
forge script script/DeploySafe.s.sol:DeploySafe \
  --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY

forge script script/DeployFactory.s.sol:DeployFactory \
  --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY
```

After each deploy, capture: contract address, tx hash, block height, deployer address (the broadcast log prints them).

## 6. Smoke-test on testnet

```bash
forge script script/CheckDeployment.s.sol:CheckDeployment \
  --rpc-url sentrix_testnet --private-key $DEPLOYER_PRIVATE_KEY
```

Should report `OK` for every contract. Any `MISMATCH` or `UNREACHABLE` = stop, investigate before mainnet.

## 7. Deploy mainnet

Repeat step 5 with `--rpc-url sentrix_mainnet`. Same order: WSRX → Multicall3 → Safe → Factory.

If anything goes wrong on mainnet, **halt the validators** (per the `feedback_mainnet_restart_cascade_jailing` rule in operator runbooks) and investigate before continuing. Founder controls all 4 mainnet validators today, so this is recoverable.

## 8. Update `deployments/`

Append the deployed addresses to `deployments/7119.json` (mainnet) and `deployments/7120.json` (testnet):

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

## 9. Copy ABIs

```bash
./script/copy-abi.sh
```

This pulls each compiled artifact from `out/<Contract>.sol/<Contract>.json` into `deployments/abi/`. Commit the result.

## 10. Update CHANGELOG.md + RELEASES.md

- `CHANGELOG.md`: bump `[Unreleased]` → `[vX.Y.Z]` with `### Deployed` block
- `RELEASES.md`: append rows to the release log table

## 11. Tag + push

```bash
git tag vX.Y.Z
git push --tags
```

## 12. (Optional) Verify on Sourcify

```bash
forge script script/VerifyAll.s.sol:VerifyAll \
  --rpc-url sentrix_mainnet
```

Sourcify integration is pending (T1-1 ecosystem readiness sprint). Until that lands, this script logs the verification commands you would run manually.

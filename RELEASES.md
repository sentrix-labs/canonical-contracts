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
| _none yet — initial repo scaffold_ | | | | | | | |

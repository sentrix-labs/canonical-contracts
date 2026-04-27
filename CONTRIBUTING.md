# Contributing

Thanks for considering a contribution to Sentrix canonical contracts.

## Workflow

1. **Fork** the repo
2. **Branch** off `main` (`git checkout -b feat/your-change`)
3. **Open a PR** against `main`
4. CI must pass (`forge test`, `forge build`, `forge fmt --check`) before merge

## Required checks

- `forge test` — all tests pass
- `forge build` — compiles cleanly with solc 0.8.24
- `forge fmt --check` — formatting matches `foundry.toml` `[fmt]` config
- No secrets leaked (pre-commit hook + CI gitleaks)

## Adding a new contract

1. Drop the Solidity source in `contracts/`
2. Add a deploy script in `script/Deploy<Name>.s.sol`
3. Add tests in `test/<Name>.t.sol` covering happy path + at least one revert path
4. Open PR; do NOT include deployment addresses yet (that happens at release-tag time)

## After deploying

Every coordinated deploy to mainnet + testnet must update:

- `CHANGELOG.md` — new release entry under `## [vX.Y.Z]` with `### Deployed` block
- `deployments/7119.json` + `deployments/7120.json` — new contract → address mapping
- `RELEASES.md` — append a row to the release log table (date, contract, address, tx hash, deployer, block)

These doc updates land as a follow-up commit on `main` after the deploy completes successfully on both networks.

## Style

- Solidity: solc 0.8.24, optimizer on (200 runs), no `via_ir`, no external imports unless documented in source comment
- Naming: PascalCase contracts, camelCase functions, SCREAMING_SNAKE_CASE constants
- License: top-of-file SPDX header (`BUSL-1.1` for new originals; `MIT` only for verbatim mirrors of public-domain standards like Multicall3)
- Comments: explain the *why* (consensus invariant, gas trade-off, security check), not the *what*

## Questions

Open a GitHub Discussion or email `dev@sentrixchain.com`.

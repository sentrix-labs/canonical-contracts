<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/sentrix-labs/brand-kit@master/png-transparent/sentrix-labs-256.png" alt="Sentrix Labs" width="120">
</p>

<h1 align="center">Sentrix Canonical Contracts</h1>

<p align="center"><strong>Production EVM contracts for <a href="https://sentrixchain.com">Sentrix Chain</a> — WSRX, Multicall3, SentrixSafe, TokenFactory.</strong></p>

<p align="center">
  <a href="https://github.com/sentrix-labs/canonical-contracts/actions/workflows/ci.yml"><img src="https://github.com/sentrix-labs/canonical-contracts/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/sentrix-labs/canonical-contracts/actions/workflows/security.yml"><img src="https://github.com/sentrix-labs/canonical-contracts/actions/workflows/security.yml/badge.svg" alt="Security"></a>
  <img src="https://img.shields.io/badge/license-BUSL--1.1-black" alt="License">
  <img src="https://img.shields.io/badge/solc-0.8.24-blue" alt="Solidity">
  <img src="https://img.shields.io/badge/foundry-stable-orange" alt="Foundry">
</p>

---

## What's in here

| Contract | Purpose |
|---|---|
| [`WSRX`](contracts/WSRX.sol) | Wrapped SRX — ERC-20 (18 decimals) backed 1:1 by native SRX. Lets EVM dApps hold SRX as a token. |
| [`Multicall3`](contracts/Multicall3.sol) | Standard Multicall3 ([mds1/multicall](https://github.com/mds1/multicall)) for batched read/write calls. |
| [`SentrixSafe`](contracts/SentrixSafe.sol) | Minimal multi-sig wallet (Gnosis Safe v1.4.1-derived) for treasury management. Currently configured 1-of-1 with the Sentrix Labs authority signer (`0xa25236925bc10954e0519731cc7ba97f4bb5714b`) on both chains — see [`docs/ADDRESSES.md`](docs/ADDRESSES.md#sentrixsafe-ownership). |
| [`TokenFactory`](contracts/TokenFactory.sol) | Deploys minimal ERC-20 tokens via a single function call. |

**Network:** Sentrix Mainnet `7119` + Sentrix Testnet `7120` — see [`docs/ADDRESSES.md`](docs/ADDRESSES.md) for deployed addresses.

## Quickstart

```bash
git clone --recurse-submodules https://github.com/sentrix-labs/canonical-contracts.git
cd canonical-contracts

# Install Foundry: https://getfoundry.sh
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Install dependencies
make install

# Build + test
make build
make test

# Coverage
make coverage     # outputs coverage/lcov.info
```

## Integrate

```bash
npm install @sentrix-labs/canonical-contracts ethers
```

```ts
import { ethers } from "ethers";
import abi from "@sentrix-labs/canonical-contracts/deployments/abi/WSRX.json";
import deployments from "@sentrix-labs/canonical-contracts/deployments/7119.json";

const provider = new ethers.JsonRpcProvider("https://rpc.sentrixchain.com");
const wsrx = new ethers.Contract(deployments.WSRX.address, abi.abi, provider);
console.log("totalSupply:", await wsrx.totalSupply());
```

Full integration guide → [`docs/INTEGRATION.md`](docs/INTEGRATION.md).

## Deploy

End-to-end runbook: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md). High-level flow:

```bash
cp .env.example .env
$EDITOR .env

forge script script/DeployWSRX.s.sol --rpc-url sentrix_testnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY
forge script script/DeployWSRX.s.sol --rpc-url sentrix_mainnet --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Update deployments/7119.json + 7120.json + CHANGELOG.md
# Tag release
git tag v1.0.0 && git push --tags
```

CI auto-creates a GitHub Release from the CHANGELOG entry.

## Verify

Sourcify-equivalent verification is on the ecosystem readiness Tier 1 backlog. Until that lands, run manual verification per [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) §12.

Health-check a deployment:

```bash
WSRX_ADDR=0x... MULTICALL3_ADDR=0x... SAFE_ADDR=0x... FACTORY_ADDR=0x... \
  forge script script/CheckDeployment.s.sol --rpc-url sentrix_testnet
```

## Security

- All contracts immutable (no upgrade proxy — see [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md))
- Pre-merge: `forge test`, `forge build --sizes`, `slither`, `gitleaks`
- Daily: scheduled slither + mythril runs ([`security.yml`](.github/workflows/security.yml))
- Vulnerability disclosure: `security@sentrixchain.com` ([`SECURITY.md`](SECURITY.md))

## Docs

| Doc | What it covers |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Contract relationships + 8↔18 decimal conversion |
| [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) | Step-by-step deploy runbook |
| [`docs/INTEGRATION.md`](docs/INTEGRATION.md) | Code examples (ethers, wagmi) |
| [`docs/SECURITY_MODEL.md`](docs/SECURITY_MODEL.md) | Trust assumptions + threat model |
| [`docs/ADDRESSES.md`](docs/ADDRESSES.md) | Deployed addresses (auto-gen) |
| [`docs/FAQ.md`](docs/FAQ.md) | Common questions |
| [`docs/STORAGE_LAYOUT.md`](docs/STORAGE_LAYOUT.md) | Storage slots per contract |
| [`docs/AUDIT.md`](docs/AUDIT.md) | Audit status + findings (when available) |

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). PRs welcome — `forge test` + `forge fmt --check` + `slither --fail-high` must pass before merge.

## Community

- **GitHub Discussions** — https://github.com/sentrix-labs/canonical-contracts/discussions for integration questions, contract design feedback, deployment help.
- **Org profile** — https://github.com/sentrix-labs

## License

BUSL-1.1 (see [`LICENSE`](LICENSE) + [`NOTICE`](NOTICE)). Change Date: 2030-01-01 → MIT.

`Multicall3.sol` is a verbatim mirror of [mds1/multicall](https://github.com/mds1/multicall) (MIT) — license preserved in the file's SPDX header.

---

<p align="center"><sub>Built by <a href="https://github.com/sentrix-labs">Sentrix Labs</a> for <a href="https://sentrixchain.com">Sentrix Chain</a>.</sub></p>

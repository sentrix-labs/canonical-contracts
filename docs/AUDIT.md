# Audit Status

| Field | Value |
|---|---|
| Status | **PENDING** (external audit Q2 2026) |
| External auditor | TBD — engagement planned Q2 2026 |
| Internal review | Continuous via CI: `slither` + `mythril` on every PR; manual review by Sentrix Labs / SentrisCloud security team |
| Scope | All four contracts in `contracts/` (`WSRX.sol`, `Multicall3.sol`, `SentrixSafe.sol`, `TokenFactory.sol`) + deploy scripts in `script/` |
| Lines of Solidity | ~1,500 LoC across 4 contracts |
| Findings | None yet (pre-external-audit; internal review findings tracked in PR history) |
| Last updated | 2026-04-28 |

## External audit plan

**Status:** Engagement targeted for Q2 2026 per Sentrix tokenomics roadmap §9. Specific firm selection and audit timeline will be announced when engagement is signed.

**Budget:** Allocated from Sentrix Strategic Reserve (see [tokenomics docs](https://docs.sentrixchain.com/tokenomics/OVERVIEW)).

External audit completion is a prerequisite for major CEX listings.

## Pre-audit posture

These contracts are deployed **before** a third-party audit. The chain is currently bootstrap-phase with Foundation-operated validators and a 1-of-1 SentrixSafe — a security incident here would be operationally recoverable. Despite that, the contracts are designed for minimum attack surface:

- **`Multicall3`** is a verbatim mirror of an established public contract (`mds1/multicall`), deployed across most major EVM chains. The deployed bytecode matches the canonical reference. Audit risk: low — pattern is industry-standard.
- **`WSRX`** is a minimal WETH9-style wrapper. The wrap/unwrap pattern is well-understood (WETH on Ethereum has trillions of dollars of cumulative volume across decade+ of operation). Audit risk: low — minimal logic, no admin keys.
- **`SentrixSafe`** is derived from Gnosis Safe v1.4.1 but **trimmed** to the execute-from-N-of-M-owners core. No modules, no guards, no fallback handlers. Smaller attack surface vs. full Gnosis Safe, but also fewer eyes on this exact code. Audit risk: medium — primary external audit focus.
- **`TokenFactory`** deploys minimal ERC-20 tokens with no admin keys post-deploy. Each deployed token is a fresh contract; factory is not upgradeable. Audit risk: low — open factory pattern.

## Continuous internal review

CI gates on every PR:

- **`forge test`** — unit + invariant tests
- **`slither`** — static analyzer with `--fail-high` (blocks merge on high-severity findings)
- **`mythril`** — symbolic execution (catches reachability + logic errors)
- **`gitleaks`** — secret scanning
- **Manual review** — every PR reviewed by Sentrix Labs / SentrisCloud security team before merge

CI configuration: [`.github/workflows/security.yml`](../.github/workflows/security.yml).

## When to re-run audit

- Any time a contract is added or modified materially
- Before any v2 deploy of any canonical contract
- Annually for the canonical set as a whole
- Following any major chain protocol upgrade that changes contract assumptions (e.g., gas accounting changes)

## Reporting issues

See [`SECURITY.md`](../SECURITY.md) for vulnerability disclosure policy.

- `security@sentrixchain.com` for non-public reports
- Safe-harbor policy applies — researchers acting in good faith are protected from legal action
- Acknowledgement within 48 hours; remediation timeline depends on severity

## Cross-references

- [`SECURITY.md`](../SECURITY.md) — disclosure policy + safe-harbor terms
- [Sentrix chain audit summary](https://docs.sentrixchain.com/security/AUDIT_SUMMARY) — chain-level audit history (separate from contracts)
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — per-contract design rationale
- [`STORAGE_LAYOUT.md`](STORAGE_LAYOUT.md) — storage slot layout (relevant for proxy upgrade audits)

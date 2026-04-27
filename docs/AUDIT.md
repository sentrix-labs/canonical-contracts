# Audit Status

| Field | Value |
|---|---|
| Status | **PENDING** |
| Auditor | TBD |
| Scope | All four contracts in `contracts/` (`WSRX.sol`, `Multicall3.sol`, `SentrixSafe.sol`, `TokenFactory.sol`) + deploy scripts in `script/` |
| Findings | None yet (pre-audit) |
| Last updated | 2026-04-27 |

## Pre-audit posture

These contracts are deployed **before** a third-party audit. Risk mitigations:

- `Multicall3` is a verbatim mirror of an established public contract (`mds1/multicall`, deployed across most major chains)
- `WSRX` is a minimal WETH9-style wrapper — pattern is well-understood
- `SentrixSafe` is derived from Gnosis Safe v1.4.1 but **trimmed** — fewer features = smaller attack surface, but also fewer eyes on this exact code
- `TokenFactory` deploys minimal ERC-20 tokens with no admin keys post-deploy

CI runs `forge test` + `slither` static analysis on every PR. `slither --fail-high` blocks merge on high-severity findings.

## When to re-run audit

- Any time a contract is added or modified materially
- Before any v2 deploy
- Annually for the canonical set

## Reporting issues

See `SECURITY.md` for vulnerability disclosure. `security@sentrixchain.com` for non-public reports.

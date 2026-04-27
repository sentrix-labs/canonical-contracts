# Security Model

## Trust assumptions

| Actor | Trust level | What they can do |
|---|---|---|
| **End user** | Untrusted | Send native SRX, deposit/withdraw via WSRX, deploy tokens via factory, sign Safe txs (if owner) |
| **Deployer EOA** | Trusted at deploy time only | Deploys initial canonical contracts, then retired (key off-rotation post-deploy) |
| **SentrixSafe owners** | Trusted (multisig) | Govern the multi-sig itself — add/remove owners, change threshold, execute treasury txs |
| **Validators** | Trusted (network-level) | Order + finalize transactions; cannot mint or steal SRX (consensus enforced) |

## Per-contract surface

| Contract | Owner | Upgrade | Pause |
|---|---|---|---|
| `WSRX` | None (immutable) | No upgrade path | No pause |
| `Multicall3` | None (immutable) | No upgrade | No pause |
| `TokenFactory` | None (open factory) | No upgrade | No pause |
| `SentrixSafe` | Self-governed | Owners + threshold mutable via self-call | No pause; emergency = revoke owners |

**No proxy. No pause.** Canonical contracts are immutable. A bug requires a `vN+1` deploy and a migration advisory in `RELEASES.md`.

## Threat model

### Rug-pull

- WSRX has no admin. A malicious party cannot drain the underlying SRX pool — every withdrawal is gated by per-account `balanceOf`.
- `TokenFactory` deploys ERC-20 tokens **with no admin keys** (no mint, no pause, no upgrade) — the deployer of a token gets the initial supply, but that's it. The token is yours.
- `SentrixSafe` requires N-of-M ECDSA signatures for any treasury action; single owner cannot drain.

### Replay attack

- WSRX, Multicall3, TokenFactory: standard EOA → contract calls protected by EVM nonce.
- SentrixSafe: per-tx nonce + `block.chainid` in EIP-712 domain separator. Cross-chain replay impossible.

### Reentrancy

- `WSRX.withdraw`: state updated **before** the native call (`balanceOf -= wad; totalSupply -= wad; (call); event`). Standard checks-effects-interactions. No reentrancy.
- `Multicall3`: callees can re-enter, but each call is independent and doesn't share mutable state.
- `SentrixSafe.execTransaction`: nonce incremented before external call; reentrant Safe calls fail signature check on stale nonce.

### Signature malleability

- `SentrixSafe` uses native `ecrecover` — vulnerable to `s` malleability if not bounded. Mitigation: enforce signers sorted ascending in `checkSignatures`. Higher-`s` form maps to a different recovered address than the canonical low-`s`, so a malleable sig would fail the strict-ascending order check.

### Validator collusion

If 2/3+ validators collude, they could censor or front-run user txs. This is the standard L1 trust assumption — does not affect smart-contract security per se, but limits what guarantees the canonical contracts can offer.

## Emergency procedure

If an exploit is discovered against a canonical contract:

1. **Operator response**: notify `security@sentrixchain.com`, internal triage
2. **Chain-level halt** (if active draining): halt mainnet validators per the operator chain-halt runbook (founder controls all 4 today)
3. **Diagnose** — root-cause via tx history + state snapshot
4. **Fix** — write `vN+1` of the affected contract on a security branch, internal review, audit if possible
5. **Resume** — restart validators, deploy `vN+1`, advise migration in `RELEASES.md` + public `SECURITY.md` advisory
6. **Post-mortem** — public write-up after the fix is in production

## Signature verification specifics (SentrixSafe)

- Threshold N out of M: caller submits `signatures = sig1 || sig2 || ... || sigN` (concatenated 65-byte ECDSA each)
- Signatures sorted by signer address ascending — duplicate signer impossible because `currentOwner > lastOwner` is strict
- `dataHash` = EIP-712 hash of `SafeTx(to, value, data, operation, nonce)`
- `ecrecover` standard; no `s` clamping (relies on sort-order to defeat malleability — see Threat model)

## Audit posture

See `docs/AUDIT.md`. Pre-audit deploy is acceptable for the current scope (immutable, minimal surface, public-domain references for Multicall3) but a formal audit before v1 mainnet is encouraged.

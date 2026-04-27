# Audits

External + internal audits of the canonical contracts. Drop PDFs here as they arrive.

## Status

| Audit | Status | Auditor | Date | PDF |
|---|---|---|---|---|
| Initial canonical set v1.0.0 | **PENDING** | TBD | TBD | (not yet) |
| WSRX | PENDING | TBD | TBD | — |
| Multicall3 | N/A (verbatim mirror of audited public contract) | — | — | — |
| SentrixSafe | PENDING | TBD | TBD | — |
| TokenFactory | PENDING | TBD | TBD | — |

## How to add an audit report

1. Save the PDF here as `<auditor>-<contract>-<YYYY-MM-DD>.pdf`
2. Update the table above with link + date
3. Mention any findings + remediation status in `docs/AUDIT.md`
4. If findings require code changes, open a security-branch PR and link the audit PDF in the PR description

## Internal review

Every PR to `main` gets a CI pass (`forge test`, `slither`, `gitleaks`). Internal review is documented in PR comments — for the audit-traceability layer, reference the PR number when describing a contract change in the audit report.

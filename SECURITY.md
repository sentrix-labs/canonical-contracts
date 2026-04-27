# Security policy

## Secrets

- **Never commit `.env` or any file containing a private key.** `.gitignore` blocks `.env*` patterns; the pre-commit hook in this repo re-checks. If you suspect a leak, rotate the key immediately and notify `security@sentrixchain.com`.
- The deployer key for canonical contracts lives off-repo in operator-internal storage. Reference it via the `DEPLOYER_PRIVATE_KEY` env var only — never inline in scripts.

## Vulnerability disclosure

Email **`security@sentrixchain.com`** with reproducer + impact assessment. Use PGP if available (key fingerprint published at `https://sentrixchain.com/security`). We respond within 72 hours.

Do not file public issues for security bugs.

## Immutability

Deployed contracts here are **immutable** — there is no upgrade proxy in the canonical set. Audit thoroughly before mainnet deploy. The deploy-script flow is: feature branch → CI green → merge to `main` → testnet deploy → operator manual smoke → mainnet deploy. Mainnet deploy is the point of no return; if a vulnerability is found post-deploy, the response is "deploy v2 + advise migration", not "patch in place."

## Scope

In scope:
- All contracts in `contracts/`
- All deploy scripts in `script/`
- Foundry config + CI workflow

Out of scope (covered elsewhere):
- Sentrix node / consensus (sentrix-labs/sentrix repo)
- Faucet UI / explorer / wallets (sentriscloud/* repos)

# Copilot Instructions

Follow the repository-specific guidance in `AGENTS.md`.

Key constraints:

- This is an employee endpoint security attestation app, not MDM or EDR.
- Preserve manual review paths for platforms that cannot inspect security
  controls automatically, especially iOS, Android, and web.
- Keep submissions compatible with the signed envelope and Apps Script backend.
- Run `make check` for substantive changes.
- Use Release Please-compatible Conventional Commit titles for PRs and commits
  that will land on `main`.

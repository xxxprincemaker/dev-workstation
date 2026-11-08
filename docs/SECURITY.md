# Security & reversibility notes — V8

## Permission and trust boundaries

- Run `install.sh` as an ordinary user; the script may invoke `sudo` to install OS packages or manage the Docker service on Linux. Do not pipe random internet content into `sudo bash`.
- `--check` / `--plan` inspect installed software, local package metadata, and generated configuration previews. They don't invoke package installations, clone repos, change shells, or delete user files. They may query metadata via package-manager commands.
- `--yes` approves install **stages only**. It cannot approve package upgrades (`--yes-updates`) or elevated-risk operations (Docker group membership, login-shell change, destructive uninstall).
- Explicit `--confirm-remove=REMOVE` only bypasses the **global** uninstall acknowledgment; sensitive removals still have per-item confirmations. When not interactive, such actions are kept.
- Docker group membership grants root-equivalent privileges. Docker Desktop can require separate terms/licensing and manual startup on macOS.

## Inventory and rollback

- V8 records its ownership in `${XDG_STATE_HOME:-~/.local/state}/dev-workstation/ledger-v8.tsv`. It does not assume ownership of V7 tools or your pre-existing packages.
- V8-managed file updates are copied into `state/backups/<transaction-id>/`. The before/after SHA-256 digests prevent automatic replacement of a file the user has edited since the tool modified it.
- `--rollback` restores **managed configuration files** and safely tracked links from the last transaction; it does **not** downgrade package-manager packages, installed Java/Go toolchains, NVM packages, downloaded binaries, Kubernetes clusters, or external services.
- `--uninstall --all` only removes resources V8 actually records and can still validate. Extensible directories (NVM, SDKMAN, LazyVim, Git clones, Go/Java installations) require `--purge-user-data` *and* a separate confirmation, because they may now contain user data.
- Avoid sharing the state ledger, backups, and `~/.zshrc` without inspecting them: they can reveal machine paths or local configurations.

## Sources and checksums

- GitHub direct binaries with SHA-256 release digests, and downloads from Go/Adoptium/Helm/kubectl with verified published hashes, are checked before installation where supported by the V7 module code.
- Some official bootstrap scripts such as NVM, SDKMAN, Homebrew, and Oh My Zsh rely on HTTPS and source trust, not V8-verified content hashes. Do not treat them as reproducible or supply-chain attested.
- `config/versions.lock` is an **audit/reference file**, not an enforced software lock. Some plugin Git clones follow mutable branches. Pin and audit commit SHAs before using this in a tightly controlled organization.
- The V7-derived installers were reorganized and wrapped by V8, but their complete network/OS behavior was not exercised in these tests. Use a disposable VM first.
- The macOS smoke test mocks Darwin/Homebrew detection. It is not proof of successful real Mac setup.

## Sensitive data intentionally excluded

The export function writes only the desired profile and a version snapshot. It never exports SSH private keys, kubeconfigs, passwords, authentication tokens, environment secrets, Docker credentials or Git repositories.

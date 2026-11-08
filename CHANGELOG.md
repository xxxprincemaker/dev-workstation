# Changelog

## 8.0.0 — Workstation Manager

- Converted the V7 monolithic installer into separate `lib/` and `modules/` files.
- Added English menu and confirmation prompts, optionally using the already-installed `gum` command.
- Added read-only cross-platform inventory, health probes and per-tool change plan.
- Added `--plan --diff` previews for Zsh, tmux and Neovim managed files.
- Separated install-stage approval (`--yes`) from version upgrade approval (`--yes-updates`).
- Added SHA-256-tracked changes, protected backups and a V8-only ownership inventory.
- Added conservative uninstall and partial file/link rollback with post-install modification detection.
- Added portable settings export without private credential data.
- Retained V7 ecosystems: Java, Node/NVM, Go, Docker/Compose, Kubernetes, terminal and full-dev tools.
- Added Linux and simulated macOS smoke tests plus CI configuration.

## Known limitations

- Platform package availability differs; some optional tools may be skipped.
- Live installation, update, and destructive uninstall have not been executed end-to-end on real Macs and all Linux distributions.
- Plugins and package versions are not fully locked to immutable references.
- The V8 inventory deliberately does not adopt packages installed by the V7 script without proof of ownership.
- Rollback cannot undo system package upgrades or changes made by external installers.

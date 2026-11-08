# Dev Workstation V8 — Workstation Manager

**Interactive menus and confirmation questions are in English.** The main user guide is available in Portuguese: [docs/GUIA-PT-BR.md](docs/GUIA-PT-BR.md).

A modular workstation bootstrap for macOS (Homebrew) and Linux (APT, DNF, pacman, zypper). Supports Java 25 LTS / optional Java 21, SDKMAN/Maven/Gradle, Node LTS/NVM/npm/Corepack/pnpm/Yarn, Go, Docker/Compose, Kubernetes/kubectl/Helm, Terraform/Ansible and related tooling, Zsh/Spaceship, Neovim/LazyVim/Markdown and tmux Pro.

## Quick start

```bash
chmod +x install.sh
./install.sh --check
./install.sh --plan --full-dev --diff
./install.sh --menu
# or install missing components with individual confirmations:
./install.sh --install --full-dev
```

Other operations:

```bash
./install.sh --update --full-dev
./install.sh --only=tmux --install
./install.sh --markdown-only --install
./install.sh --uninstall --all --dry-run
./install.sh --uninstall --all
./install.sh --rollback
./install.sh --export-profile=my-workstation.toml
```

`--yes` approves installation stages but NEVER individual updates. `--yes-updates` is required to approve version upgrades non-interactively, paired with `--yes` to approve the stage itself. Deletion remains separately guarded.

## How the V8 differs from V7

The V7 installation logic has been preserved as separate language, infrastructure and terminal modules. New V8 components include OS discovery, a per-tool plan, English prompts with optional Gum menus, read-only file diffs, SHA-256 tracked configuration changes, a separate V8 ownership ledger, selective uninstall/rollback and portable profile export.

**Important limitations:** the complete install/update/uninstall process on physical macOS and every supported Linux distribution has not been tested. Package dependencies may be changed by the underlying package manager; plugin updates in Neovim remain manual. Rollback protects managed files, not package upgrades. V7-managed resources are not automatically adopted. See [Security](docs/SECURITY.md).

## Structure

- `install.sh`: CLI and menu entrypoint.
- `lib/`: platform discovery, package adapters, interaction, inventory, planning, previews, export and safety.
- `modules/`: Java/Node/Go/Docker, infrastructure, Zsh/tmux/Neovim (V7-derived workflows).
- `config/workstation.toml`: desired profile and feature toggles.
- `config/versions.lock`: audit reference for bootstrap sources (not enforced).
- `tests/test_smoke.sh`: fast, non-destructive tests.
- `.github/workflows/ci.yml`: CI matrix, Ubuntu and macOS.

## Tests

```bash
bash tests/test_smoke.sh
bash -n install.sh
./install.sh --check --only=tmux
```

No automatic installation is launched by these tests.

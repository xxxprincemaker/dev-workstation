#!/usr/bin/env bash
# Dev Workstation V8 — modular cross-platform installer.
# Bash 3.2+, English menus, Portuguese documentation.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"
. "$ROOT/lib/platform.sh"
. "$ROOT/lib/ui.sh"
. "$ROOT/lib/settings.sh"
. "$ROOT/lib/inventory.sh"
. "$ROOT/lib/packages.sh"
. "$ROOT/lib/planner.sh"
. "$ROOT/lib/operations.sh"
. "$ROOT/modules/languages.sh"
. "$ROOT/modules/infrastructure.sh"
. "$ROOT/modules/terminal.sh"
. "$ROOT/lib/preview.sh"
. "$ROOT/lib/doctor.sh"
. "$ROOT/lib/export.sh"
help() {
cat <<'HELP'
Dev Workstation V8 — Java, Go, Node, Docker, Kubernetes, Zsh, tmux, LazyVim
Usage: ./install.sh [MODE] [OPTIONS]

MODES (no mode: interactive menu on TTY, check in non-interactive environments)
  --menu                 Interactive action menu (English)
  --check                Read-only inventory and environment diagnostics
  --plan                 Preview an installation plan (alias: --install --dry-run)
  --install              Install missing tools, never update installed packages
  --update               Review newer versions, never auto-update without permission
  --uninstall --all      Uninstall only V8-owned artifacts, with safety checks
  --rollback             Restore changed V8-managed files from last transaction
  --export-profile=FILE  Export portable settings and version snapshot

OPTIONS
  --full-dev             Backend + infrastructure tools and editor extras
  --only=STAGES          Comma-separated selection (java,node,go,tmux,neovim,...)
  --tmux-only            Equivalent to --only=tmux
  --markdown-only        Configure LazyVim Markdown without reinstalling Neovim
  --java21               Include JDK 21 alongside JDK 25
  --no-terminal          Skip Zsh, tmux, Neovim, Nerd Font
  --no-nerd-font         Skip font installation
  --set-default-shell    Offer to change login shell (separate risk confirmation)
  --config=FILE          Read simple TOML configuration (default config/workstation.toml)
  --replace-config       Permit overwriting modified/personal configs after backups
  --dry-run              Show plan, change nothing
  --diff                 Show limited unified diffs for managed configuration files
  --yes                  Approve install stages only; NEVER approves updates/removal
  --yes-updates          Approve detected package/release updates; only in --update
  --purge-user-data      Permit separately confirmed deletion of managed extensible dirs
  --confirm-remove=REMOVE  Uninstall acknowledgment (per-item risk checks still apply)
  --help                 Show this help

Bash 3.2+, macOS Homebrew; Linux apt/dnf/pacman/zypper.
Do NOT run the entry script with sudo. Run --plan first.
HELP
}
CONFIG_FILE="$ROOT/config/workstation.toml"
EXPORT_PROFILE_FILE=''
for argument in "$@"; do
  case "$argument" in --config=*) CONFIG_FILE="${argument#*=}";; esac
done
load_settings "$CONFIG_FILE"
for argument in "$@"; do
  case "$argument" in
    --menu) MODE=menu;;
    --check) MODE=check;;
    --plan) MODE=install; DRY_RUN=1;;
    --install) MODE=install;;
    --update) MODE=update;;
    --uninstall) MODE=uninstall;;
    --rollback) MODE=rollback;;
    --export-profile=*) MODE=export; EXPORT_PROFILE_FILE="${argument#*=}";;
    --all) REMOVE_ALL=1;;
    --dry-run) DRY_RUN=1;;
    --diff) SHOW_DIFF=1;;
    --full-dev) PROFILE=full;;
    --only=*) ONLY="${argument#*=}";;
    --tmux-only) ONLY=tmux;;
    --markdown-only) ONLY=markdown;;
    --java21) JAVA21=1;;
    --no-terminal) NO_TERMINAL=1;;
    --no-nerd-font) NO_FONT=1;;
    --set-default-shell) SET_DEFAULT_SHELL=1;;
    --replace-config) REPLACE_CONFIG=1;;
    --yes) YES=1;;
    --yes-updates) YES_UPDATES=1;;
    --purge-user-data) PURGE_USER_DATA=1;;
    --confirm-remove=*) CONFIRM_REMOVE="${argument#*=}";;
    --config=*) :;;
    --help|-h) help; exit 0;;
    *) die "Unknown option: $argument. See --help.";;
  esac
done
if [[ "$EUID" -eq 0 && "$MODE" != check && "$MODE" != export && "$DRY_RUN" -eq 0 ]]; then
  die 'Do not run the installer as root; use your normal user.'
fi
[[ "$YES_UPDATES" -eq 0 || "$MODE" == update ]] || die '--yes-updates requires --update.'
[[ "$PURGE_USER_DATA" -eq 0 || "$MODE" == uninstall ]] || die '--purge-user-data requires --uninstall.'
[[ "$MODE" != uninstall || "$REMOVE_ALL" -eq 1 || -n "$ONLY" ]] || die 'Uninstall requires --all or --only=...'
[[ -z "$ONLY" || "$ONLY" =~ ^[a-z]+(,[a-z]+)*$ ]] || die 'Invalid --only value.'
for requested in ${ONLY//,/ }; do
  [[ -z "$requested" ]] && continue
  case " $STAGES markdown " in *" $requested "*) :;; *) die "Unknown stage: $requested";; esac
done
[[ -z "$ONLY" || "$NO_TERMINAL" -eq 0 || "$ONLY" != markdown ]] || die '--markdown-only conflicts with --no-terminal.'
detect_os
if [[ "$MODE" == menu ]]; then main_menu; fi
[[ "$MODE" != exit ]] || exit 0
if [[ "$MODE" == check && "$DRY_RUN" -eq 1 ]]; then warn 'Check is already read-only.'; fi
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dev-workstation-v8.XXXXXXXX")"
V8_TX="$(date -u +%Y%m%dT%H%M%SZ)-$$"
report_environment
if [[ "$MODE" == uninstall ]]; then uninstall_managed; exit 0; fi
if [[ "$MODE" == export ]]; then export_profile "$EXPORT_PROFILE_FILE"; exit 0; fi
if [[ "$MODE" == rollback ]]; then rollback_latest; exit 0; fi
if [[ "$MODE" == install || "$MODE" == check || "$MODE" == update ]]; then
  build_plan
  show_plan
  preview_configs
  if [[ "$MODE" == check ]]; then health_report; fi
fi
if [[ "$MODE" == check || "$DRY_RUN" -eq 1 ]]; then
  log 'Read-only assessment complete. No software or user configurations were changed.'
  exit 0
fi
acquire_lock || die 'Failed to obtain V8 lock'
if [[ "$PLATFORM" == macos && -z "$BREW" ]]; then
  if ! ensure_brew; then die 'Homebrew required for macOS installation; nothing else was changed.'; fi
fi
# Refresh metadata only with explicit approval; never run pacman -Sy (partial sync).
if [[ "$PKG" != pacman ]]; then
  if { [[ "$MODE" == update && "$YES_UPDATES" -eq 1 ]]; } || \
     confirm_risk "Refresh $PKG package metadata before applying changes?"; then
    if init_package_cache; then
      log 'Metadata refreshed. Updated package plan:'
      build_plan
      show_plan
    else
      warn 'Metadata refresh failed; continue with cached package information.'
    fi
  fi
fi
run_stage() {
  case "$1" in
    basics) setup_basics;;
    java) setup_java;;
    sdkman) setup_sdkman;;
    node) setup_node;;
    go) setup_go; setup_go_tools;;
    docker) setup_docker;;
    kubernetes) setup_k8s;;
    terminal) setup_terminal_deps;;
    zsh)
      if ! command_exists zsh; then optional_package zsh zsh; fi
      setup_shell_env; setup_zsh;;
    tmux)
      if ! command_exists tmux; then optional_package tmux tmux; fi
      setup_tmux_pro;;
    neovim)
      if [[ "$ONLY" == markdown ]]; then setup_markdown_only
      else setup_nvim; fi;;
    font)
      if [[ "$MODE" != update ]]; then setup_font
      else log 'Font update not managed automatically; use --install or Homebrew manually.'; fi;;
    infra)
      setup_full_cli
      if [[ "$NO_TERMINAL" -eq 0 ]]; then
        if [[ -f "$HOME/.config/nvim/lua/config/lazy.lua" ]]; then merge_lazyvim; fi
        generate_full_dev_zsh
        write_owned "$CONFIG_DIR/full-dev.zsh" "$TMP_DIR/full-dev.zsh" '# dev-bootstrap-linux: zsh-full-managed'
        generate_tmux_full_conf
        write_owned "$CONFIG_DIR/tmux-full.conf" "$TMP_DIR/tmux-full.conf" '# dev-bootstrap-linux: tmux-full-managed'
      fi
      ;;
    *) die "Unknown stage: $1";;
  esac
}
# Updates never install package dependencies behind the user's back: stage-by-stage
# approval precedes calling the ecosystem handler. External installers may still
# have their own dependency resolution; review their own prompts before proceeding.
for stage in $STAGES; do
  is_selected "$stage" || continue
  if [[ "$MODE" == update && "$stage" == font ]]; then
    log '[SKIP] Font updates must be requested explicitly using the package manager'
    continue
  fi
  if [[ "$MODE" == update ]] && ! stage_has_change "$stage"; then
    log "[SKIP] $(stage_title "$stage"): no potential update detected"
    continue
  fi
  if [[ "$MODE" == install ]] && ! stage_has_change "$stage"; then
    case "$stage" in java|node|font|sdkman) :;; *) log "[SKIP] $(stage_title "$stage"): tools already available"; continue;; esac
  fi
  printf '\n===== %s =====\n' "$(stage_title "$stage")"
  if [[ "$MODE" == update ]]; then
    approve_step "Inspect/apply updates for $(stage_title "$stage")? Each newer version requires separate approval." || { log '[SKIP] Stage declined'; continue; }
  else
    approve_step "Install missing tools/configuration for $(stage_title "$stage")?" || { log '[SKIP] Stage declined'; continue; }
  fi
  run_stage "$stage"
  SUCCESS_STAGES=$((SUCCESS_STAGES+1))
done
ok "Finished $SUCCESS_STAGES selected stages. Run --check to inspect and verify versions."
warn 'Some optional tools may be unavailable on this OS. Neovim plugins need :Lazy sync / :LazyHealth.'
warn 'Docker Desktop on macOS must be opened manually; kubectl installs a client, not a cluster.'

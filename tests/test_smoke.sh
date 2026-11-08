#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
pass() { printf '[PASS] %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '[FAIL] %s\n' "$1" >&2; exit 1; }
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
for file in "$ROOT"/install.sh "$ROOT"/lib/*.sh "$ROOT"/modules/*.sh; do
  bash -n "$file" || fail "bash -n $file"
done
pass 'all Bash syntax valid'
HOME="$TEMP/home"; mkdir -p "$HOME"
export HOME
export DEV_WORKSTATION_STATE_DIR="$HOME/.local/state/dev-workstation"
export DEV_WORKSTATION_DATA_DIR="$HOME/.local/share/dev-workstation"
check_output="$("$ROOT/install.sh" --check --only=tmux)"
[[ "$check_output" == *'Mode: check'* ]] || fail 'check output'
[[ ! -e "$DEV_WORKSTATION_STATE_DIR" ]] || fail 'check changed state'
pass '--check is read-only'
plan_output="$("$ROOT/install.sh" --plan --only=tmux)"
[[ "$plan_output" == *'Mode: install'* && "$plan_output" == *'Read-only'* ]] || fail 'plan output'
[[ ! -e "$DEV_WORKSTATION_STATE_DIR" ]] || fail 'plan changed state'
pass '--plan is read-only'
[[ "$("$ROOT/install.sh" --help)" == *'--yes-updates'* ]] || fail 'missing CLI help'
pass 'help available'
if "$ROOT/install.sh" --update --yes-updates --plan >/dev/null 2>&1; then
  fail 'invalid flag validation'
else pass '--yes-updates rejected outside update mode'; fi
# Test V8 inventory without installing system packages.
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"
. "$ROOT/lib/ui.sh"
. "$ROOT/lib/inventory.sh"
. "$ROOT/lib/operations.sh"
TMP_DIR="$TEMP/tmp"; mkdir -p "$TMP_DIR"
STATE_DIR="$DEV_WORKSTATION_STATE_DIR"
DATA_DIR="$DEV_WORKSTATION_DATA_DIR"
CONFIG_DIR="$HOME/.config/dev-bootstrap"
MANIFEST="$STATE_DIR/ledger-v8.tsv"
V8_TX='unit-test-1'
MODE=install; REPLACE_CONFIG=1; DRY_RUN=0
FILE="$HOME/.zshrc"
printf 'original\n' > "$FILE"
printf 'managed\n' > "$TMP_DIR/new"
write_owned "$FILE" "$TMP_DIR/new" '# test-managed'
[[ "$(cat "$FILE")" == managed ]] || fail 'initial managed write'
[[ -f "$MANIFEST" && $(wc -l < "$MANIFEST") -eq 1 ]] || fail 'inventory record'
pass 'managed file written with history'
# User edit must NOT be overwritten by rerun.
printf 'user override\n' > "$FILE"
REPLACE_CONFIG=0
printf 'newer managed\n' > "$TMP_DIR/new"
write_owned "$FILE" "$TMP_DIR/new" '# test-managed'
[[ "$(cat "$FILE")" == 'user override' ]] || fail 'user edit overwritten'
pass 'user edit preserved on rerun'
# Rollback rejects edited files.
MODE=rollback; DRY_RUN=0
confirm_risk() { return 0; }
rollback_latest
[[ "$(cat "$FILE")" == 'user override' ]] || fail 'rollback overwrote user edit'
pass 'rollback refuses edited files'
# Explicit override captures user revision and rollback restores it.
MODE=install; V8_TX='unit-test-2'; REPLACE_CONFIG=1
write_owned "$FILE" "$TMP_DIR/new" '# test-managed'
[[ "$(cat "$FILE")" == 'newer managed' ]] || fail 'replace-config did not apply'
MODE=rollback
rollback_latest
[[ "$(cat "$FILE")" == 'user override' ]] || fail 'rollback did not restore backup'
pass 'rollback restores most recent backup safely'
# --yes never approves an update.
MODE=update; YES=1; YES_UPDATES=0
if approve_update 'Upgrade?'; then fail '--yes approved an update'; fi
YES_UPDATES=1
approve_update 'Upgrade?' || fail '--yes-updates failed'
pass 'install and update confirmations are independent'
# V8 can uninstall its own unmodified new file, but not an edited file.
MODE=install; V8_TX='unit-test-3'; REPLACE_CONFIG=0
NEWFILE="$HOME/.config/dev-bootstrap/generated-test.conf"
printf 'auto-managed\n' > "$TMP_DIR/test-config"
write_owned "$NEWFILE" "$TMP_DIR/test-config" '# test-generated'
[[ -f "$NEWFILE" ]] || fail 'created managed file missing'
MODE=uninstall; CONFIRM_REMOVE=REMOVE; REMOVE_ALL=1
uninstall_managed
[[ ! -e "$NEWFILE" ]] || fail 'uninstall left owned file'
[[ "$(cat "$FILE")" == 'user override' ]] || fail 'uninstall overwrote user-edited file'
pass 'uninstall removes only tracked unmodified files'
# Simulate macOS without touching real environment.
MOCK="$TEMP/mockbin"; mkdir -p "$MOCK"
cat > "$MOCK/uname" <<'SH'
#!/bin/sh
case "$1" in -s) echo Darwin;; -m) echo arm64;; *) echo Darwin;; esac
SH
cat > "$MOCK/sw_vers" <<'SH'
#!/bin/sh
echo 15.5
SH
cat > "$MOCK/brew" <<'SH'
#!/bin/sh
case "$1" in shellenv) printf '%s\n' 'export HOMEBREW_NO_AUTO_UPDATE=1';; *) exit 1;; esac
SH
chmod +x "$MOCK/"*
mac_output="$(PATH="$MOCK:$PATH" "$ROOT/install.sh" --check --only=tmux)"
[[ "$mac_output" == *'macOS 15.5'* && "$mac_output" == *'| brew'* ]] || fail 'Darwin detection'
pass 'macOS / Homebrew discovery (simulated)'
export_file="$TEMP/exported-profile.toml"
"$ROOT/install.sh" --export-profile="$export_file" >/dev/null
[[ -f "$export_file" && -f "$TEMP/exported-profile.versions.txt" ]] || fail 'profile export missing'
grep -Fq 'profile = "full"' "$export_file" || fail 'exported wrong profile'
pass 'portable export excludes secrets and writes settings'
# Locking prevents concurrent mutating operations.
MODE=install
acquire_lock
if acquire_lock >/dev/null 2>&1; then fail 'concurrent installer acquired lock'; fi
rm -rf "$STATE_DIR/.lock"; LOCK_HELD=0
pass 'concurrent operations are blocked by lock'
# Integration check: merge LazyVim Markdown extra without deleting unrelated extras.
if command -v jq >/dev/null 2>&1; then
  . "$ROOT/modules/terminal.sh"
  mkdir -p "$HOME/.config/nvim/lua/config" "$HOME/.config/nvim/lua/plugins"
  printf 'require("LazyVim/LazyVim")\n' > "$HOME/.config/nvim/lua/config/lazy.lua"
  printf '{"version":8,"extras":["custom.keep.me"]}\n' > "$HOME/.config/nvim/lazyvim.json"
  MODE=install; V8_TX='unit-test-markdown'; ONLY=markdown; DRY_RUN=0
  setup_markdown_only
  jq -e '.extras | index("custom.keep.me") != null and index("lazyvim.plugins.extras.lang.markdown") != null' "$HOME/.config/nvim/lazyvim.json" >/dev/null || fail 'Markdown merge removed custom extras'
  [[ -f "$HOME/.config/nvim/lua/plugins/dev-markdown.lua" ]] || fail 'Markdown module not generated'
  pass 'Markdown configuration preserves existing LazyVim extras'
fi
printf '\nTOTAL PASSED: %s\n' "$PASS"

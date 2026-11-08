# Inventory and file-tracking — every V8 row contains six nonempty TSV fields.
# type name ref sha_before sha_after transaction
init_state() {
  umask 077
  mkdir -p "$STATE_DIR" "$DATA_DIR" "$STATE_DIR/backups" "$HOME/.local/bin" "$CONFIG_DIR"
  [[ -f "$MANIFEST" ]] || : > "$MANIFEST"
}
acquire_lock() {
  # mkdir is an atomic lock primitive on macOS/Linux filesystems.
  umask 077
  mkdir -p "$STATE_DIR"
  if ! mkdir "$STATE_DIR/.lock" 2>/dev/null; then
    warn "Another V8 operation may be running (lock: $STATE_DIR/.lock)."
    warn 'Verify that no installation is active before manually removing a stale lock.'
    return 1
  fi
  LOCK_HELD=1
  printf '%s\n' "$$" > "$STATE_DIR/.lock/pid"
}
record() {
  local typ="$1" name="$2" ref="${3:--}" before="${4:--}" after="${5:--}"
  ((DRY_RUN)) && return 0
  safe_field "$typ" && safe_field "$name" && safe_field "$ref" || die 'Unexpected tab/newline in inventory entry.'
  init_state
  [[ -n "$ref" ]] || ref='-'
  [[ -n "$before" ]] || before='-'
  [[ -n "$after" ]] || after='-'
  if [[ "$after" == '-' ]]; then
    case "$typ" in
      binary|created|systemfile) [[ -f "$name" && ! -L "$name" ]] && after="$(sha_file "$name")";;
      link) [[ -L "$name" ]] && ref="$(readlink "$name")";;
    esac
  fi
  local existing=''
  # Avoid recording identical ownership records repeatedly across reinstallations.
  if [[ "$typ" != file && "$typ" != binary && -f "$MANIFEST" ]]; then
    existing="$(awk -F '\t' -v t="$typ" -v n="$name" '$1==t && $2==n{found=1} END{print found+0}' "$MANIFEST")"
    [[ "$existing" != 1 ]] || return 0
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$typ" "$name" "$ref" "$before" "$after" "${V8_TX:--}" >> "$MANIFEST"
}
owned() {
  [[ -f "$MANIFEST" ]] || return 1
  awk -F '\t' -v t="$1" -v n="$2" '$1==t && $2==n{f=1} END{exit !f}' "$MANIFEST"
}
latest_managed_hash() {
  [[ -f "$MANIFEST" ]] || { printf '-'; return 0; }
  awk -F '\t' -v n="$1" '$1=="file" && $2==n{h=$5} END{print h?h:"-"}' "$MANIFEST"
}
config_marker() {
  local target="$1" marker="$2"
  [[ -f "$target" ]] || return 1
  grep -Fq "$marker" "$target" 2>/dev/null && return 0
  grep -Eq 'dev-bootstrap-linux:|dev-workstation-v7:' "$target" 2>/dev/null && return 0
  # JSON merge is conservative: the source is a merge with original extras.
  [[ "$target" == "$HOME/.config/nvim/lazyvim.json" && "$marker" == '"extras"' ]]
}
write_owned() {
  local target="$1" src="$2" marker="$3" before='-' after='' backup='-' previous='-'
  [[ -f "$src" ]] || { warn "Missing generated source: $src"; return 1; }
  if [[ -L "$target" ]]; then warn "Symlink preserved: $target"; return 0; fi
  if [[ -d "$target" ]]; then warn "Directory preserved (expected file): $target"; return 0; fi
  if [[ -f "$target" ]] && cmp -s "$src" "$target"; then return 0; fi
  if [[ -f "$target" ]]; then
    before="$(sha_file "$target")"
    previous="$(latest_managed_hash "$target")"
    if [[ "$previous" != '-' && "$before" != "$previous" && "$REPLACE_CONFIG" -eq 0 ]]; then
      warn "Modified since last managed write; keeping $target (use --replace-config to override)"; return 0
    fi
    if [[ "$previous" == '-' && "$REPLACE_CONFIG" -eq 0 ]] && ! config_marker "$target" "$marker"; then
      warn "Personal configuration preserved: $target (use --replace-config)"; return 0
    fi
  fi
  if ((DRY_RUN)); then log "[PLAN] Write $target"; return 0; fi
  init_state
  mkdir -p "$(dirname "$target")" "$STATE_DIR/backups/$V8_TX"
  if [[ -f "$target" ]]; then
    backup="$(mktemp "$STATE_DIR/backups/$V8_TX/file.XXXXXXXX")"
    cp -p "$target" "$backup"
  fi
  local temp
  temp="$(mktemp "$(dirname "$target")/.dev-workstation.XXXXXXXX")"
  cp "$src" "$temp"
  chmod 0644 "$temp"
  mv -f "$temp" "$target"
  after="$(sha_file "$target")"
  record file "$target" "$backup" "$before" "$after"
  ok "Managed configuration: $target"
}
append_managed_line() {
  local target="$1" marker="$2" line="$3" temp
  [[ ! -L "$target" ]] || { warn "Symlink preserved: $target"; return 0; }
  if [[ -f "$target" ]] && grep -Fq "$marker" "$target"; then return 0; fi
  temp="$(mktemp "$TMP_DIR/append.XXXXXXXX")"
  [[ -f "$target" ]] && cp "$target" "$temp" || : > "$temp"
  printf '\n%s\n%s\n' "$marker" "$line" >> "$temp"
  # Appending known delimited lines is safe; preserve old content in backup.
  # Avoid replace-config requirement by passing the unique marker condition.
  if [[ -f "$target" && "$REPLACE_CONFIG" -eq 0 ]] && ! config_marker "$target" "$marker"; then
    local old_replace="$REPLACE_CONFIG"
    REPLACE_CONFIG=1
    write_owned "$target" "$temp" "$marker"
    REPLACE_CONFIG="$old_replace"
  else
    write_owned "$target" "$temp" "$marker"
  fi
}
add_shell_line() {
  local target="$1" line="$2" marker="$3"
  append_managed_line "$target" "$marker" "$line"
}
safe_user_path() {
  local p="$1"
  case "$p" in *'/../'*|*'/./'*|*'/..'|*'/.'|*$'\n'*|*$'\t'*) return 1;; esac
  case "$p" in
    "$HOME/.config/"*|"$HOME/.local/"*|"$HOME/.tmux/"*|"$HOME/.oh-my-zsh/"*|\
    "$HOME/.nvm"|"$HOME/.sdkman"|"$HOME/.tmux.conf"|"$HOME/.zshrc"|\
    "$HOME/.bashrc"|"$HOME/.spaceshiprc.zsh"|"$HOME/.oh-my-zsh"|\
    "$HOME/go/bin/"*|"$HOME/.atuin/"*) return 0;;
  esac
  return 1
}
safe_system_path() {
  case "$1" in *'/../'*|*'/..'|*'/./'*|*'/.'|*$'\n'*|*$'\t'*) return 1;; esac
  case "$1" in
    /etc/apt/keyrings/dev-workstation-*|/etc/apt/sources.list.d/dev-workstation-*) return 0;;
  esac
  return 1
}

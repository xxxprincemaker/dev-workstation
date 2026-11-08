# Operations / uninstall / rollback. No guess-based ownership.
# Fields: type name ref before after tx. Safeguards apply even when --yes is given.
load_ledger_reverse() {
  [[ -s "$MANIFEST" ]] || return 0
  awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}' "$MANIFEST"
}
confirm_remove_global() {
  local response=''
  if ((DRY_RUN)); then return 0; fi
  [[ "$CONFIRM_REMOVE" == REMOVE ]] && return 0
  [[ -t 0 ]] || die 'Uninstall requires a terminal or explicit --confirm-remove=REMOVE.'
  printf '\nType REMOVE to begin removal of V8-managed items: ' > /dev/tty
  IFS= read -r response < /dev/tty || return 1
  [[ "$response" == REMOVE ]] || { warn 'Uninstall cancelled.'; return 1; }
}
verify_file_after() {
  local name="$1" expected="$2"
  [[ -f "$name" && ! -L "$name" ]] || return 1
  [[ "$(sha_file "$name")" == "$expected" ]]
}
remove_ledger_entry() {
  local typ="$1" name="$2" ref="$3" before="$4" after="$5" tx="$6"
  local origin='' candidate=''
  case "$typ" in
    file)
      safe_user_path "$name" || { warn "Unsafe managed file path: $name"; return 1; }
      [[ -e "$name" || -L "$name" ]] || return 0
      if ! verify_file_after "$name" "$after"; then
        warn "Preserving edited/unknown file: $name (hash differs from installed version)"; return 1
      fi
      if [[ "$ref" == '-' ]]; then
        log "[REMOVE] file $name"
        ((DRY_RUN)) && return 1
        rm -f -- "$name"
      else
        [[ -f "$ref" && ! -L "$ref" ]] || { warn "Missing backup: $ref"; return 1; }
        case "$ref" in "$STATE_DIR/backups/"*) : ;; *) warn "Backup outside state: $ref"; return 1 ;; esac
        [[ "$(sha_file "$ref")" == "$before" ]] || { warn "Backup checksum mismatch: $ref"; return 1; }
        log "[RESTORE] $name from V8 backup"
        ((DRY_RUN)) && return 1
        cp -p "$ref" "$name"
      fi
      ;;
    created|binary|link)
      safe_user_path "$name" || { warn "Unsafe item: $name"; return 1; }
      [[ -e "$name" || -L "$name" ]] || return 0
      if [[ "$after" != '-' && ( "$typ" == binary || "$typ" == created ) ]] && ! verify_file_after "$name" "$after"; then
        warn "File edited since installation: $name"; return 1
      fi
      if [[ "$typ" == link ]]; then
        [[ -L "$name" ]] || { warn "Not a symlink anymore: $name"; return 1; }
        if [[ "$ref" != '-' && "$(readlink "$name")" != "$ref" ]]; then
          warn "Symlink target changed: $name"; return 1
        fi
      fi
      if [[ "$typ" == created && "$PURGE_USER_DATA" -eq 0 ]]; then warn "Conservative removal: $name requires --purge-user-data"; return 1; fi
      log "[REMOVE] $typ $name"
      ((DRY_RUN)) && return 1
      rm -f -- "$name"
      ;;
    dir|repo|nvm|sdkman|sdk_candidate)
      if [[ "$typ" == sdk_candidate ]]; then name="$ref"; fi
      safe_user_path "$name" || { warn "Unsafe directory: $name"; return 1; }
      [[ -d "$name" && ! -L "$name" ]] || return 0
      # Installed trees may contain new files created by the user.
      ((PURGE_USER_DATA)) || { warn "Preserving extensible directory $name; use --purge-user-data to inspect removal"; return 1; }
      if [[ "$typ" == repo ]]; then
        [[ -d "$name/.git" ]] || { warn "Git metadata missing: $name"; return 1; }
        origin="$(git -C "$name" remote get-url origin 2>/dev/null || true)"
        [[ "$origin" == "$ref" || "$origin" == "${ref%.git}" ]] || { warn "Remote changed: $name"; return 1; }
        [[ -z "$(git -C "$name" status --porcelain 2>/dev/null)" ]] || { warn "Git working tree modified: $name"; return 1; }
      fi
      log "[PURGE DIRECTORY] $name"
      ((DRY_RUN)) && return 1
      confirm_risk "Delete entire directory $name? This may contain additional user-created data." || return 1
      rm -rf -- "$name"
      ;;
    package)
      # name stores package-manager kind, ref stores the package.
      local manager="${name%%:*}" kind="${name#*:}"
      [[ "$manager" == "$PKG" ]] || { warn "Original package manager $manager differs from current $PKG"; return 1; }
      [[ -n "$ref" && "$ref" != '-' ]] || return 1
      pkg_installed "$ref" "$kind" || return 0
      log "[REMOVE PACKAGE] $ref ($PKG, installed by V8)"
      ((DRY_RUN)) && return 1
      confirm_risk "Remove package $ref? Other applications may rely on it." || return 1
      case "$PKG" in
        brew) HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" uninstall "--$kind" "$ref";;
        apt) sudo apt-get remove -y "$ref";;
        dnf) sudo dnf remove -y "$ref";;
        pacman) sudo pacman -R "$ref";;
        zypper) sudo zypper remove "$ref";;
      esac
      ;;
    systemfile)
      safe_system_path "$name" || { warn "Unsafe system path $name"; return 1; }
      [[ -f "$name" && ! -L "$name" ]] || return 0
      if [[ "$after" != '-' ]] && ! verify_file_after "$name" "$after"; then
        warn "System file was edited; preserving: $name"; return 1
      fi
      log "[REMOVE MANAGED SYSTEM FILE] $name"
      ((DRY_RUN)) && return 1
      confirm_risk "Remove managed system file $name?" || return 1
      sudo rm -f -- "$name"
      ;;
    npm_global)
      warn "npm global $name: preserving; remove explicitly with npm uninstall -g $name"; return 1;;
    manager|group)
      warn "$typ $name requires manual review and is never removed automatically"; return 1;;
    *) warn "Unknown inventory type $typ, preserving"; return 1;;
  esac
  return 0
}
rewrite_ledger_without() {
  local removed="$1" tmp
  [[ -s "$removed" ]] || return 0
  tmp="$(mktemp "$STATE_DIR/ledger.XXXXXXXX")"
  awk 'NR==FNR{removed[$0]++;next} !removed[$0]' "$removed" "$MANIFEST" > "$tmp"
  mv "$tmp" "$MANIFEST"
}
select_entry_for_only() {
  local name="$1" ref="$2"
  [[ -z "$ONLY" ]] && return 0
  case ",$ONLY," in
    *',tmux,'*) case "$name $ref" in *tmux*|*'.tmux.conf'*) return 0;; esac;;
    *',markdown,'*|*',neovim,'*) case "$name $ref" in *nvim*|*lazyvim*) return 0;; esac;;
  esac
  return 1
}
uninstall_managed() {
  [[ -s "$MANIFEST" ]] || { warn 'No V8 inventory. V7-owned resources are intentionally not guessed.'; return 0; }
  log "Inventory: $MANIFEST"
  local typ name ref before after tx removed_file="$TMP_DIR/removed.tsv" deleted=0 retained=0
  : > "$removed_file"
  if ! confirm_remove_global; then return 0; fi
  while IFS=$'\t' read -r typ name ref before after tx; do
    [[ -n "$typ" ]] || continue
    select_entry_for_only "$name" "$ref" || continue
    if remove_ledger_entry "$typ" "$name" "$ref" "$before" "$after" "$tx"; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$typ" "$name" "$ref" "$before" "$after" "$tx" >> "$removed_file"
      deleted=$((deleted+1))
    else retained=$((retained+1)); fi
  done < <(load_ledger_reverse)
  if ((DRY_RUN)); then log "Preview: $((deleted+retained)) entries inspected; no changes."
  else rewrite_ledger_without "$removed_file"; ok "Uninstalled: $deleted, preserved: $retained"; fi
}
rollback_latest() {
  [[ -s "$MANIFEST" ]] || { warn 'No completed V8 transaction in ledger.'; return 0; }
  local last_tx typ name ref before after tx restored=0 untouched=0 removed_file="$TMP_DIR/rollback.tsv"
  last_tx="$(awk -F '\t' 'NF>=6 && $6!="-" {t=$6} END{print t}' "$MANIFEST")"
  [[ -n "$last_tx" ]] || { warn 'No rollbackable transaction'; return 0; }
  log "Latest transaction: $last_tx"
  : > "$removed_file"
  if ((DRY_RUN)); then log 'Rollback preview only.'
  elif ! confirm_risk "Rollback V8-managed files created or changed in $last_tx? Packages and tool versions cannot be automatically downgraded."; then return 0; fi
  while IFS=$'\t' read -r typ name ref before after tx; do
    [[ "$tx" == "$last_tx" ]] || continue
    case "$typ" in
      file|link)
        if remove_ledger_entry "$typ" "$name" "$ref" "$before" "$after" "$tx"; then
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$typ" "$name" "$ref" "$before" "$after" "$tx" >> "$removed_file"
          restored=$((restored+1))
        else untouched=$((untouched+1)); fi;;
      *) warn "Rollback cannot safely reverse $typ ($name); kept for uninstall/manual review"; untouched=$((untouched+1));;
    esac
  done < <(load_ledger_reverse)
  if ((DRY_RUN)); then ok "Rollback preview complete."
  else rewrite_ledger_without "$removed_file"; ok "Restored $restored entries; other/changed entries preserved: $untouched"; fi
}

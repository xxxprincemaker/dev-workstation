# Read-only preview of proposed managed file changes.
preview_one() {
  local target="$1" src="$2" marker="$3" action='CREATE'
  [[ -f "$src" ]] || return 0
  if [[ -L "$target" ]]; then action='PRESERVE (symlink)'
  elif [[ -f "$target" ]] && cmp -s "$target" "$src"; then action='UNCHANGED'
  elif [[ -f "$target" ]] && ! config_marker "$target" "$marker" && [[ "$REPLACE_CONFIG" -eq 0 ]]; then action='PRESERVE (custom)'
  elif [[ -f "$target" ]]; then action='MODIFY'; fi
  printf '  [%-20s] %s\n' "$action" "$target"
  if [[ "$SHOW_DIFF" -eq 1 && ( "$action" == CREATE || "$action" == MODIFY ) ]]; then
    local old="$target"
    [[ -f "$target" ]] || old=/dev/null
    diff -u "$old" "$src" 2>/dev/null | awk 'NR<=35{print "    "$0} END{if(NR>35) print "    ... (diff truncated, " NR " lines total)"}' || true
  fi
}
preview_configs() {
  printf '\nCONFIGURATION FILE CHANGES (read-only preview)\n'
  if is_selected zsh; then
    generate_dev_spaceshiprc_zsh
    preview_one "$HOME/.spaceshiprc.zsh" "$TMP_DIR/dev-spaceshiprc.zsh" '# dev-bootstrap-linux: spaceship-managed'
    generate_dev_terminal_zsh
    preview_one "$CONFIG_DIR/terminal.zsh" "$TMP_DIR/dev-terminal.zsh" '# dev-bootstrap-linux: terminal-extras-managed'
    generate_dev_zshrc
    preview_one "$CONFIG_DIR/zshrc.generated" "$TMP_DIR/dev-zshrc" '# dev-bootstrap-linux: terminal-managed'
    if [[ -f "$HOME/.zshrc" ]] && ! config_marker "$HOME/.zshrc" '# dev-bootstrap-linux: terminal-managed'; then
      printf '  [APPEND (with backup)] %s — source generated zshrc\n' "$HOME/.zshrc"
    else
      preview_one "$HOME/.zshrc" "$TMP_DIR/dev-zshrc" '# dev-bootstrap-linux: terminal-managed'
    fi
    if [[ "$PROFILE" == full ]]; then
      generate_full_dev_zsh
      preview_one "$CONFIG_DIR/full-dev.zsh" "$TMP_DIR/full-dev.zsh" '# dev-bootstrap-linux: zsh-full-managed'
    fi
  fi
  if is_selected tmux; then
    generate_tmux_help_txt
    preview_one "$CONFIG_DIR/tmux-help.txt" "$TMP_DIR/tmux-help.txt" 'TMUX PRO — QUICK REFERENCE'
    generate_tmux_ui_conf
    preview_one "$CONFIG_DIR/tmux-ui.conf" "$TMP_DIR/tmux-ui.conf" '# dev-bootstrap-linux: tmux-ui-managed'
    generate_dev_tmux_conf
    preview_one "$CONFIG_DIR/tmux-main.conf" "$TMP_DIR/dev-tmux.conf" '# dev-bootstrap-linux: tmux-managed'
    if [[ -f "$HOME/.tmux.conf" ]] && ! config_marker "$HOME/.tmux.conf" '# dev-bootstrap-linux: tmux-managed'; then
      printf '  [APPEND (with backup)] %s — source generated tmux config\n' "$HOME/.tmux.conf"
    else
      preview_one "$HOME/.tmux.conf" "$TMP_DIR/dev-tmux.conf" '# dev-bootstrap-linux: tmux-managed'
    fi
    if [[ "$PROFILE" == full ]]; then
      generate_tmux_full_conf
      preview_one "$CONFIG_DIR/tmux-full.conf" "$TMP_DIR/tmux-full.conf" '# dev-bootstrap-linux: tmux-full-managed'
    fi
  fi
  if is_selected neovim; then
    generate_dev_markdown_lua
    preview_one "$HOME/.config/nvim/lua/plugins/dev-markdown.lua" "$TMP_DIR/dev-markdown.lua" '-- dev-bootstrap-linux: markdown-managed'
    if [[ "$ONLY" != markdown ]]; then
      generate_dev_bootstrap_lua
      preview_one "$HOME/.config/nvim/lua/plugins/dev-bootstrap.lua" "$TMP_DIR/dev-bootstrap.lua" '-- dev-bootstrap-linux: lazyvim-managed'
    fi
    printf '  [MERGE (preserve extras)] %s\n' "$HOME/.config/nvim/lazyvim.json"
  fi
  printf 'Files outside these managed paths are never implicitly replaced.\n'
}

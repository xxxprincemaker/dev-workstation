# Read-only functional checks; do not start services or download plugins.
probe() {
  local label="$1" binary="$2"; shift 2
  if ! command_exists "$binary"; then
    printf '  [MISSING] %-18s command unavailable\n' "$label"; return 0
  fi
  if "$binary" "$@" >/dev/null 2>&1; then
    printf '  [OK]      %-18s %s\n' "$label" "$(command -v "$binary")"
  else
    printf '  [WARNING] %-18s command found but health probe failed\n' "$label"
  fi
}
health_report() {
  printf '\nREAD-ONLY HEALTH PROBES\n'
  probe Git git --version
  probe Java java -version
  probe Node node --version
  probe npm npm --version
  probe Go go version
  probe Docker-CLI docker --version
  if command_exists docker; then
    if docker info >/dev/null 2>&1; then printf '  [OK]      Docker-daemon      reachable\n'
    else printf '  [WARNING] Docker-daemon      not reachable (Desktop not running / permissions)\n'; fi
    if docker compose version >/dev/null 2>&1; then printf '  [OK]      Docker-Compose     v2 available\n'
    else printf '  [WARNING] Docker-Compose     CLI plugin missing\n'; fi
  fi
  probe kubectl kubectl version --client
  probe Helm helm version --short
  probe Neovim nvim --version
  probe tmux tmux -V
  probe Zsh zsh --version
  if [[ -f "$HOME/.config/nvim/lua/config/lazy.lua" ]]; then
    printf '  [INFO]    LazyVim            configuration present (plugins not executed)\n'
  fi
  if [[ -f "$HOME/.tmux.conf" ]]; then
    printf '  [INFO]    tmux.conf          present (not executed)\n'
  fi
  printf 'Run :LazyHealth inside Neovim to inspect plugins; kubectl client probe does not test a cluster.\n'
}

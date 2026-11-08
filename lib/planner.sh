# Declarative plan; package values are manager-specific where known.
STAGES='basics java sdkman node go docker kubernetes terminal zsh tmux neovim font infra'
stage_title() {
  case "$1" in
    basics) printf 'Base CLI and build tools';;
    java) printf 'Java LTS';;
    sdkman) printf 'SDKMAN / Maven / Gradle';;
    node) printf 'NVM / Node LTS / package managers';;
    go) printf 'Go and Go tools';;
    docker) printf 'Docker and Compose';;
    kubernetes) printf 'Kubernetes CLI and Helm';;
    terminal) printf 'Terminal utilities';;
    zsh) printf 'Zsh / Oh My Zsh / Spaceship';;
    tmux) printf 'tmux Pro';;
    neovim) printf 'Neovim / LazyVim / Markdown';;
    font) printf 'Nerd Font';;
    infra) printf 'Backend and Infra full-dev';;
    *) printf '%s' "$1";;
  esac
}
stage_spec() {
  # name:command:formula[:cask] — use '-' for unmanaged direct binaries.
  case "$1" in
    basics) printf '%s\n' 'Git:git:git' 'Curl:curl:curl' 'jq:jq:jq' 'ripgrep:rg:ripgrep' 'Python:python3:python3' 'fzf:fzf:fzf';;
    java) if [[ "$PLATFORM" == macos ]]; then printf '%s\n' 'Java25:java:temurin@25:cask'; else printf '%s\n' 'Java25:java:-'; fi;;
    sdkman) printf '%s\n' 'Maven:mvn:-' 'Gradle:gradle:-' 'SDKMAN:sdk:-';;
    node) printf '%s\n' 'Node:node:-' 'npm:npm:-' 'Corepack:corepack:-' 'pnpm:pnpm:-' 'Yarn:yarn:-';;
    go) printf '%s\n' 'Go:go:go' 'gopls:gopls:-' 'goimports:goimports:-';;
    docker) if [[ "$PLATFORM" == macos ]]; then printf '%s\n' 'Docker:docker:docker-desktop:cask'; else printf '%s\n' 'Docker:docker:docker-ce'; fi;;
    kubernetes) if [[ "$PLATFORM" == macos ]]; then printf '%s\n' 'kubectl:kubectl:kubernetes-cli' 'Helm:helm:helm'; else printf '%s\n' 'kubectl:kubectl:-' 'Helm:helm:-'; fi;;
    terminal) printf '%s\n' 'Zsh:zsh:zsh' 'tmux:tmux:tmux' 'Lazygit:lazygit:lazygit' 'zoxide:zoxide:zoxide';;
    zsh) printf '%s\n' 'Zsh:zsh:zsh' 'Git:git:git';;
    tmux) printf '%s\n' 'tmux:tmux:tmux' 'Git:git:git';;
    neovim) printf '%s\n' 'Neovim:nvim:neovim' 'Git:git:git';;
    font) printf '%s\n' 'fontconfig:fc-list:-';;
    infra) printf '%s\n' 'Terraform:terraform:terraform' 'K9s:k9s:k9s' 'Lazydocker:lazydocker:lazydocker' 'Stern:stern:stern' 'Ansible:ansible:ansible' 'Trivy:trivy:trivy' 'TFLint:tflint:tflint' 'yq:yq:yq' 'gh:gh:gh' 'Just:just:just' 'Atuin:atuin:atuin';;
  esac
}
is_selected() {
  local stage="$1"
  [[ "$stage" != infra || "$PROFILE" == full ]] || return 1
  [[ "$stage" != font || "$NO_FONT" -eq 0 ]] || return 1
  case "$stage" in terminal|zsh|tmux|neovim|font) [[ "$NO_TERMINAL" -eq 0 ]] || return 1;; esac
  if [[ -n "$ONLY" ]]; then
    case ",$ONLY," in *",$stage,"*) return 0;; esac
    case "$ONLY:$stage" in markdown:neovim) return 0;; esac
    return 1
  fi
  return 0
}
plan_row() {
  local stage="$1" label="$2" cmd="$3" pkg="$4" kind="${5:-formula}"
  local version='-' avail='-' origin='-' action='INSTALL' current_pkg=''
  if [[ "$cmd" == sdk && -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    version='installed'; action='KEEP'; origin=SDKMAN
  elif command_exists "$cmd"; then
    version="$(tool_version "$cmd")"; action='KEEP'; origin="$(command -v "$cmd")"
  fi
  if [[ "$pkg" != '-' && "$PKG" == brew && -z "$BREW" ]]; then
    avail='Homebrew required'
  elif [[ "$pkg" != '-' ]]; then
    avail="$(pkg_candidate "$pkg" "$kind" 2>/dev/null || true)"
    [[ -n "$avail" ]] || avail='-'
    if [[ "$MODE" == update && "$action" == KEEP ]] && pkg_installed "$pkg" "$kind"; then
      current_pkg="$(pkg_current "$pkg" "$kind")"
      if [[ "$avail" != '-' && -n "$current_pkg" ]] && pkg_has_upgrade "$pkg" "$kind" "$current_pkg" "$avail" 2>/dev/null; then action='UPGRADE'; fi
    fi
  fi
  if [[ "$stage" == java && "$label" == Java25 && "$action" == KEEP ]]; then
    local jdk25=0
    if [[ "$PLATFORM" == macos ]]; then
      /usr/libexec/java_home -v 25 >/dev/null 2>&1 && jdk25=1
    else
      [[ -x "$DATA_DIR/jdks/temurin-25/bin/java" ]] && jdk25=1
      local foundmajor=''
      foundmajor="$(java -version 2>&1 | sed -nE 's/.*version "?([0-9]+).*/\1/p' | awk 'NR==1{v=$0} END{print v}' || true)"
      [[ "$foundmajor" == 25 ]] && jdk25=1
    fi
    if [[ "$jdk25" -eq 0 ]]; then action='INSTALL'; fi
  fi
  if [[ "$stage" == docker && "$action" == KEEP ]] && ! docker compose version >/dev/null 2>&1; then
    action='INSTALL'
  fi
  if [[ "$MODE" == update ]]; then
    if [[ "$action" == INSTALL ]]; then action='SKIP'; else
      if [[ "$action" == KEEP ]]; then
        if [[ "$pkg" == '-' ]]; then action='REVIEW'
        elif ! pkg_installed "$pkg" "$kind"; then action='REVIEW'; fi
      fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$stage" "$label" "$cmd" "$action" "$version" "$avail" "$origin" >> "$PLAN_FILE"
}
build_plan() {
  local stage spec label cmd pkg kind
  PLAN_FILE="$TMP_DIR/plan.tsv"
  : > "$PLAN_FILE"
  for stage in $STAGES; do
    is_selected "$stage" || continue
    while IFS= read -r spec; do
      [[ -n "$spec" ]] || continue
      IFS=: read -r label cmd pkg kind <<EOF_SPEC
$spec
EOF_SPEC
      plan_row "$stage" "$label" "$cmd" "$pkg" "${kind:-formula}"
    done <<EOF_LIST
$(stage_spec "$stage")
EOF_LIST
  done
}
show_plan() {
  local st label cmd action current available origin count=0 previous=''
  printf '\n%-18s %-17s %-10s %-23s %-22s\n' 'COMPONENT' 'TOOL' 'ACTION' 'CURRENT' 'AVAILABLE'
  printf '%s\n' '------------------------------------------------------------------------------------------------'
  while IFS=$'\t' read -r st label cmd action current available origin; do
    [[ -n "$st" ]] || continue
    if [[ "$previous" != "$st" ]]; then printf '  [%s]\n' "$(stage_title "$st")"; previous="$st"; fi
    printf '%-18s %-17s %-10s %-23.23s %-22.22s\n' "$st" "$label" "$action" "$current" "$available"
    count=$((count+1))
  done < "$PLAN_FILE"
  printf '\n%d tools inspected. AVAILABLE versions use local package metadata and can be outdated.\n' "$count"
  printf 'Config targets: ~/.zshrc, ~/.tmux.conf, ~/.config/nvim/, ~/.config/dev-bootstrap/ (only if selected).\n'
  printf 'Potential privileged changes: package installation, Docker service, and optional login-shell update.\n'
  printf 'Automatic package dependency changes are controlled by the underlying package manager.\n'
  printf 'Custom release downloads (Go, JDK, kubectl, Helm) are checked during execution.\n'
}
stage_has_change() {
  local st="$1" mode="$MODE"
  # Even if every program exists, terminal configuration may need managed changes.
  case "$st" in zsh|tmux|neovim|font) return 0;; esac
  awk -F '\t' -v s="$st" -v m="$mode" '$1==s && ($4=="INSTALL" || $4=="UPGRADE" || (m=="update" && $4=="REVIEW")) {f=1} END{exit !f}' "$PLAN_FILE"
}

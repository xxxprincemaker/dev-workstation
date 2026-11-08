# Platform/OS discovery; no root privileges required.
detect_os() {
  local os
  os="$(uname -s)"
  ARCH="$(uname -m)"
  case "$os" in
    Darwin)
      PLATFORM=macos; DISTRO=macos
      DISTRO_NAME="macOS $(sw_vers -productVersion 2>/dev/null || true)"
      PKG=brew
      if command_exists brew; then BREW="$(command -v brew)"
      elif [[ -x /opt/homebrew/bin/brew ]]; then BREW=/opt/homebrew/bin/brew
      elif [[ -x /usr/local/bin/brew ]]; then BREW=/usr/local/bin/brew; fi
      if [[ -n "$BREW" ]]; then
        # Brew shellenv prints plain shell environment exports.
        eval "$("$BREW" shellenv)"
      fi
      ;;
    Linux)
      PLATFORM=linux
      [[ -r /etc/os-release ]] || die '/etc/os-release not found.'
      # shellcheck disable=SC1091
      . /etc/os-release
      DISTRO="${ID:-linux}"; DISTRO_NAME="${PRETTY_NAME:-Linux}"
      VERSION_CODENAME="${VERSION_CODENAME:-}"
      if command_exists apt-get && command_exists dpkg-query; then PKG=apt
      elif command_exists dnf; then PKG=dnf
      elif command_exists pacman; then PKG=pacman
      elif command_exists zypper; then PKG=zypper
      else die 'Unsupported Linux package manager. Expected apt, dnf, pacman or zypper.'; fi
      ;;
    *) die "Unsupported system: $os" ;;
  esac
  export PATH="$HOME/.local/bin:$DATA_DIR/go/current/bin:$DATA_DIR/nvim/current/bin:$HOME/go/bin:$HOME/.atuin/bin:$PATH"
  export NVM_DIR SDKMAN_DIR
}
report_environment() {
  printf '\nDEV WORKSTATION V%s | %s | %s | %s\n' "$SCRIPT_VERSION" "$DISTRO_NAME" "$ARCH" "$PKG"
  printf 'Mode: %-12s Profile: %-8s Data: %s\n' "$MODE" "$PROFILE" "$STATE_DIR"
}

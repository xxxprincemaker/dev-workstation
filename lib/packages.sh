# Package manager adapters. Refactored from the V7 implementation.
pkg_installed() {
  local p="$1" kind="${2:-formula}"
  case "$PKG" in
    brew)
      [[ -n "$BREW" ]] || return 1
      if [[ "$kind" == cask ]]; then "$BREW" list --cask --versions "$p" 2>/dev/null | awk '/[0-9]/ {f=1} END {exit !f}'
      else "$BREW" list --formula --versions "$p" 2>/dev/null | awk '/[0-9]/ {f=1} END {exit !f}'; fi;;
    apt) [[ "$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null || true)" == 'install ok installed' ]];;
    dnf) rpm -q "$p" >/dev/null 2>&1;;
    pacman) pacman -Qq "$p" >/dev/null 2>&1;;
    zypper) rpm -q "$p" >/dev/null 2>&1;;
  esac
}
pkg_current() {
  local p="$1" kind="${2:-formula}"
  case "$PKG" in
    brew) "$BREW" list --versions "${kind:+--$kind}" "$p" 2>/dev/null | awk '{print $2}' ;;
    apt) dpkg-query -W -f='${Version}' "$p" 2>/dev/null || true;;
    dnf|zypper) rpm -q --qf '%{VERSION}-%{RELEASE}' "$p" 2>/dev/null || true;;
    pacman) pacman -Q "$p" 2>/dev/null | awk '{print $2}';;
  esac
}
pkg_candidate() {
  local p="$1" kind="${2:-formula}"
  case "$PKG" in
    brew)
      [[ -n "$BREW" ]] || return 0
      if command -v jq >/dev/null 2>&1; then
        HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" info --json=v2 "--$kind" "$p" 2>/dev/null | jq -r '(.formula[0].versions.stable // .casks[0].version // empty)' 2>/dev/null || true
      fi;;
    apt) apt-cache policy "$p" 2>/dev/null | awk '$1 == "Candidate:" {v=$2} END {if (v!="(none)") print v}' || true;;
    dnf) dnf repoquery --latest-limit 1 --qf '%{version}-%{release}' "$p" 2>/dev/null | awk 'NR==1 {v=$0} END {print v}' || true;;
    pacman) pacman -Si "$p" 2>/dev/null | awk '/^Version[[:space:]]*:/ {v=$3} END {print v}' || true;;
    zypper) zypper --no-refresh info "$p" 2>/dev/null | awk '/^Version[[:space:]]*:/ {v=$3} END {print v}' || true;;
  esac
}
# Só atualiza quando o gerenciador comprova que o candidato é mais novo.
pkg_has_upgrade() {
  local p="$1" kind="$2" current="$3" candidate="$4" status=''
  [[ -n "$candidate" && -n "$current" && "$current" != "$candidate" ]] || return 1
  case "$PKG" in
    apt) dpkg --compare-versions "$candidate" gt "$current";;
    brew)
      # Formulae e casks podem ter revisoes/epochs, nao apenas SemVer.
      if [[ "$kind" == cask ]]; then
        HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" outdated --cask --greedy "$p" 2>/dev/null | awk 'NF {found=1} END {exit !found}'
      else
        HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" outdated --formula "$p" 2>/dev/null | awk 'NF {found=1} END {exit !found}'
      fi;;
    dnf)
      # dnf retorna 100 para pacote com atualização e 0 para atualizado.
      status=0
      dnf check-update -q "$p" >/dev/null 2>&1 || status=$?
      [[ "$status" -eq 100 ]];;
    pacman)
      warn 'Arch: partial upgrades are unsupported; run sudo pacman -Syu separately.'
      return 1;;
    zypper)
      # Se nao houver forma confiavel de comparar os EVR, nunca forçar upgrade.
      warn "zypper: valide manualmente se $candidate supera $current (zypper list-updates)."
      return 1;;
  esac
}

# Não instale uma fórmula se o binário já existe por outro gerenciador.
package() {
  local p="$1" cmd="${2:-$1}" kind="${3:-formula}" current='' available='' update=0
  if [[ "$PKG" == brew && -z "$BREW" ]]; then warn "Homebrew ausente: pacote $p ignorado."; return 0; fi
  if pkg_installed "$p" "$kind"; then
    current="$(pkg_current "$p" "$kind")"
    if [[ "$MODE" != update ]]; then ok "$cmd: existente ($current), não reinstalado"; return 0; fi
    available="$(pkg_candidate "$p" "$kind")"
    if [[ -z "$available" || "$current" == "$available" ]]; then ok "$p: versão mantida ($current), disponível: ${available:-não consultada}"; return 0; fi
    printf '  [VERSÕES] %s: instalada=%s | disponível=%s\n' "$p" "$current" "$available"
    # Diferente nao significa mais novo. Nunca provocar downgrade.
    if ! pkg_has_upgrade "$p" "$kind" "$current" "$available"; then
      ok "$p: sem atualização comprovadamente mais recente; preservado"
      return 0
    fi
    printf '  [ATUALIZAÇÃO DISPONÍVEL] %s: %s -> %s\n' "$p" "$current" "$available"
    if approve_update "Upgrade $p from $current to $available?"; then update=1; fi
    ((update)) || return 0
    if ((DRY_RUN)); then return 0; fi
    case "$PKG" in
      brew) HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" upgrade "--$kind" "$p";;
      apt) sudo apt-get install -y --no-install-recommends "$p";;
      dnf) sudo dnf upgrade -y "$p";;
      pacman) warn 'pacman não permite atualização parcial segura; execute sudo pacman -Syu manualmente.';;
      zypper) sudo zypper --non-interactive update "$p";;
    esac
    return 0
  fi
  if [[ "$MODE" == update ]]; then ok "Missing $p: install separately with --install"; return 0; fi
  if [[ -n "$cmd" ]] && command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd já existe fora de $PKG: $(command -v "$cmd"); preservado"
    return 0
  fi
  available="$(pkg_candidate "$p" "$kind")"
  printf '  [INSTALAR] %-23s atual=ausente | disponível=%s | gerenciador=%s\n' "$p" "${available:-a verificar na instalação}" "$PKG"
  ((DRY_RUN)) && return 0
  case "$PKG" in
    brew) HOMEBREW_NO_AUTO_UPDATE=1 "$BREW" install "--$kind" "$p";;
    apt) sudo apt-get install -y --no-install-recommends "$p";;
    dnf) sudo dnf install -y "$p";;
    pacman) sudo pacman -S --needed --noconfirm "$p";;
    zypper) sudo zypper --non-interactive install "$p";;
  esac
  if pkg_installed "$p" "$kind"; then record package "$PKG:$kind" "$p"; ok "$p instalado"; else warn "$p: pacote não confirmado; não será considerado de propriedade da V7"; fi
}
optional_package() {
  local p="$1" cmd="${2:-$1}" kind="${3:-formula}"
  if ! package "$p" "$cmd" "$kind"; then warn "Opcional indisponível: $p; continuando."; fi
}

# Os dois modos abaixo são exclusivos de pacotes. Nunca executam sudo em --check.
check_package() {
  local p="$1" cmd="${2:-$1}" kind="${3:-formula}" current='' available=''
  if pkg_installed "$p" "$kind"; then
    current="$(pkg_current "$p" "$kind")"
    printf ' [OK] %-22s instalado (%s)\n' "$p" "$current"
  elif [[ -n "$cmd" ]] && command -v "$cmd" >/dev/null 2>&1; then
    printf ' [OK] %-22s encontrado fora de %s\n' "$p" "$PKG"
  else
    available="$(pkg_candidate "$p" "$kind")"
    printf ' [--] %-22s ausente -> %s\n' "$p" "${available:-versão disponível não consultada}"
    ISSUES=$((ISSUES+1))
  fi
}

ensure_brew() {
  [[ "$PLATFORM" == macos ]] || return 0
  [[ -z "$BREW" ]] || { ok "Homebrew: $BREW"; return 0; }
  log 'Homebrew NÃO encontrado. Instalação oficial necessária para macOS.'
  confirm_risk 'Install Homebrew using its official installation script (admin privileges may be required)?' || return 1
  if ! xcode-select -p >/dev/null 2>&1; then
    warn 'Xcode Command Line Tools ausentes. O instalador do macOS abrirá a interface para instalar.'
    xcode-select --install || true
    die 'Conclua Command Line Tools e execute o script novamente.'
  fi
  curl -fsSL 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' -o "$TMP_DIR/brew-install.sh"
  /bin/bash "$TMP_DIR/brew-install.sh"
  if [[ -x /opt/homebrew/bin/brew ]]; then BREW=/opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then BREW=/usr/local/bin/brew
  else die 'Homebrew não foi encontrado após executar instalador.'; fi
  eval "$("$BREW" shellenv)"
  record manager brew "$BREW"
  warn 'Homebrew NÃO será desinstalado automaticamente: pode servir a outros aplicativos.'
}

init_package_cache() {
  case "$PKG" in
    apt) sudo apt-get update;;
    dnf) sudo dnf makecache -y;;
    pacman) warn 'Skipping pacman -Sy (unsafe partial repository sync). Use sudo pacman -Syu.';;
    zypper) sudo zypper --non-interactive refresh;;
    brew) : ;;
  esac
}

# Marcador de versão consultado para NVM e plugins git; erros de rede não removem nada.
latest_git_tag() {
  local repo="$1"
  command -v jq >/dev/null 2>&1 || return 0
  curl -fsSL --max-time 15 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | \
     jq -r '.tag_name // empty' 2>/dev/null || true
}
clone_managed() {
  local url="$1" dir="$2" current='' remote=''
  if [[ "$MODE" == update && ! -d "$dir/.git" ]]; then
    log "Uninstalled Git plugin $dir skipped in update mode"; return 0
  fi
  if [[ -d "$dir/.git" ]]; then
    if [[ "$MODE" == update ]] && owned repo "$dir"; then
      if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then warn "Mudanças locais em $dir, atualização ignorada"; return 0; fi
      current="$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)"
      git -C "$dir" fetch --quiet --depth=1 origin || { warn "Falha no fetch $dir"; return 0; }
      remote="$(git -C "$dir" rev-parse FETCH_HEAD 2>/dev/null || true)"
      if [[ -n "$remote" && "$remote" != "$current" ]]; then
        if approve_update "Update plugin $dir (${current:0:8} -> ${remote:0:8})?"; then
          git -C "$dir" merge --ff-only FETCH_HEAD || warn "Atualização de $dir recusada por Git"
        fi
      fi
    else ok "Plugin existente: $dir"; fi
    return 0
  fi
  if [[ -e "$dir" ]]; then warn "Diretório personalizado existente, não modificável: $dir"; return 0; fi
  ((DRY_RUN)) && { log "[PRÉVIA] git clone $url -> $dir"; return 0; }
  mkdir -p "$(dirname "$dir")"
  git clone --depth=1 "$url" "$dir"
  record repo "$dir" "$url"
}

# O bloco de módulos e configurações está abaixo.

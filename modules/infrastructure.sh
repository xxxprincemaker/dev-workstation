# Kubernetes / Infra from V7, adapted for V8.
install_verified_kubectl() {
  [[ "$MODE" != update || -f "$HOME/.local/bin/kubectl" ]] || { log 'kubectl missing, skipped in update mode'; return 0; }
  local arch_go='' version='' url='' expected='' target="$HOME/.local/bin/kubectl"
  if command -v kubectl >/dev/null 2>&1 && [[ "$MODE" != update ]]; then ok 'kubectl já instalado, preservado'; return 0; fi
  if command -v kubectl >/dev/null 2>&1 && ! owned binary "$target"; then
    ok 'kubectl externo encontrado, preserve e atualize pelo gerenciador de origem'; return 0
  fi
  case "$ARCH" in x86_64|amd64) arch_go=amd64;; aarch64|arm64) arch_go=arm64;;
    *) warn 'kubectl: arquitetura não reconhecida'; return 0;; esac
  version="$(curl -fsSL --max-time 20 https://dl.k8s.io/release/stable.txt 2>/dev/null || true)"
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { warn 'kubectl: versão remota não encontrada'; return 0; }
  if [[ -f "$target" ]]; then
    local current=''
    current="$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion // empty' || true)"
    log "kubectl: atual=${current:-não detectada} | disponível=$version"
    if ! semver_newer "$current" "$version"; then ok 'kubectl mantido (sem downgrade)'; return 0; fi
    if ! ((YES_UPDATES)) && ! answer_yes "Upgrade kubectl to $version?"; then return 0; fi
  fi
  url="https://dl.k8s.io/release/$version/bin/linux/$arch_go/kubectl"
  expected="$(curl -fsSL --max-time 20 "$url.sha256" 2>/dev/null || true)"
  expected="${expected//[[:space:]]/}"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || { warn 'kubectl sem checksum confiável'; return 0; }
  curl -fsSL --max-time 90 "$url" -o "$TMP_DIR/kubectl"
  sha256_verify "$expected" "$TMP_DIR/kubectl" || die 'kubectl checksum incorreto'
  install -m 0755 "$TMP_DIR/kubectl" "$target"
  record binary "$target" ''
}
install_verified_helm() {
  command -v jq >/dev/null 2>&1 || { warn 'Helm: jq ausente'; return 0; }
  local arch_go='' meta='' version='' file='' checksum='' target="$HOME/.local/bin/helm" current=''
  if command -v helm >/dev/null 2>&1 && [[ "$MODE" != update ]]; then ok 'Helm encontrado, preservado'; return 0; fi
  if command -v helm >/dev/null 2>&1 && ! owned binary "$target"; then ok 'Helm externo preservado'; return 0; fi
  case "$ARCH" in x86_64|amd64) arch_go=amd64;; aarch64|arm64) arch_go=arm64;;
    *) warn 'Helm: arquitetura não reconhecida'; return 0;; esac
  meta="$(curl -fsSL --max-time 25 https://api.github.com/repos/helm/helm/releases/latest 2>/dev/null || true)"
  version="$(printf '%s' "$meta" | jq -r '.tag_name // empty' 2>/dev/null || true)"
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { warn 'Helm: versão remota indisponível'; return 0; }
  if [[ -f "$target" ]]; then
    current="$("$target" version --short 2>/dev/null || true)"
    log "Helm: atual=$current | disponível=$version"
    if ! semver_newer "$current" "$version"; then ok 'Helm mantido (sem downgrade)'; return 0; fi
    if ! ((YES_UPDATES)) && ! answer_yes "Upgrade Helm to $version?"; then return 0; fi
  fi
  file="helm-$version-linux-$arch_go.tar.gz"
  curl -fsSL --max-time 90 "https://get.helm.sh/$file" -o "$TMP_DIR/$file"
  checksum="$(curl -fsSL --max-time 20 "https://get.helm.sh/$file.sha256sum" 2>/dev/null | awk 'NR==1 {print $1}' || true)"
  [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || { warn 'Helm: checksum indisponível'; return 0; }
  sha256_verify "$checksum" "$TMP_DIR/$file" || die 'Helm: checksum incorreto'
  mkdir -p "$TMP_DIR/helm-extract"
  tar -xzf "$TMP_DIR/$file" -C "$TMP_DIR/helm-extract"
  install -m 0755 "$TMP_DIR/helm-extract/linux-$arch_go/helm" "$target"
  record binary "$target" ''
}
setup_k8s() {
  if [[ "$PLATFORM" == macos ]]; then
    package kubernetes-cli kubectl
    package helm helm
  else
    install_verified_kubectl
    install_verified_helm
  fi
  warn 'kubectl instala somente o cliente. Não cria cluster nem altera kubeconfig.'
}

# Download genérico apenas para releases que publicam digest SHA256 no GitHub.
# Executáveis sem hash confiável são ignorados, não instalados silenciosamente.
github_verified() {
  local repo="$1" asset_re="$2" binary="$3" kind="${4:-tar.gz}"
  local target="$HOME/.local/bin/$binary" data='' record_line='' asset url digest found='' temp=''
  if [[ "$MODE" == update && ! -f "$target" ]]; then return 0; fi
  if command -v "$binary" >/dev/null 2>&1 && [[ "$MODE" != update ]]; then ok "$binary já disponível"; return 0; fi
  if command -v "$binary" >/dev/null 2>&1 && ! owned binary "$target"; then ok "$binary externo preservado"; return 0; fi
  command -v jq >/dev/null 2>&1 || { warn "$binary: requer jq"; return 0; }
  data="$(curl -fsSL --max-time 25 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null || true)"
  [[ -n "$data" ]] || { warn "$binary: API Github indisponível"; return 0; }
  if [[ -e "$target" && "$MODE" == update ]]; then
    local tag='' installed_ver=''
    tag="$(printf '%s' "$data" | jq -r '.tag_name // empty' || true)"
    installed_ver="$("$target" --version 2>&1 | sed -nE 's/.*v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' | awk 'NR==1 {v=$0} END {print v}' || true)"
    log "$binary: installed=${installed_ver:-unknown} | available=$tag"
    if [[ -z "$installed_ver" || ! "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      warn "$binary: cannot reliably compare installed version; skipping upgrade"; return 0
    fi
    if ! semver_newer "$installed_ver" "$tag"; then ok "$binary: no newer release"; return 0; fi
    if ! approve_update "Upgrade $binary from $installed_ver to $tag?"; then return 0; fi
  fi
  record_line="$(printf '%s' "$data" | jq -r --arg re "$asset_re" '[.assets[] | select(.name | test($re)) | [.name,.browser_download_url,(.digest // "")] | @tsv] | first // empty' 2>/dev/null || true)"
  [[ -n "$record_line" ]] || { warn "$binary: release compatível não encontrado"; return 0; }
  IFS=$'\t' read -r asset url digest <<EOF
$record_line
EOF
  [[ "$url" == "https://github.com/$repo/releases/download/"* && "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
    warn "$binary: release sem digest SHA256; ignorado"; return 0; }
  temp="$TMP_DIR/github-$(printf '%s' "$binary" | tr -cd 'a-zA-Z0-9')"
  mkdir -p "$temp"
  curl -fsSL --max-time 90 --retry 2 "$url" -o "$temp/$asset"
  sha256_verify "${digest#sha256:}" "$temp/$asset" || die "$binary: checksum SHA256 inválido"
  case "$kind" in
    tar.gz) tar -xzf "$temp/$asset" -C "$temp";;
    tar.xz) tar -xJf "$temp/$asset" -C "$temp";;
    zip) unzip -q "$temp/$asset" -d "$temp";;
    raw) cp "$temp/$asset" "$temp/$binary";;
    *) warn "Formato $kind ignorado"; return 0;;
  esac
  if [[ "$kind" == raw ]]; then found="$temp/$binary"
  else found="$(find "$temp" -type f -name "$binary" -print | awk 'NR==1 {f=$0} END {print f}')"; fi
  [[ -n "$found" && -f "$found" ]] || { warn "$binary: executável não encontrado no pacote"; return 0; }
  install -m 0755 "$found" "$target"
  record binary "$target" ''
  ok "$binary instalado, SHA256 verificado"
}

# Repositórios oficiais assinados: somente Debian/Ubuntu APT, com reversão
# limitada aos arquivos que este instalador criar.
apt_vendor_repo() {
  local provider="$1" keyurl="$2" repo_url="$3" suite="$4" pkg="$5" executable="$6"
  if [[ "$MODE" == update ]] && ! command -v "$executable" >/dev/null 2>&1; then
    log "Missing $executable: skipping vendor repository in update mode"; return 0
  fi
  [[ "$PKG" == apt ]] || return 0
  if command -v "$executable" >/dev/null 2>&1; then
    ok "$executable: instalado por outro meio, preservado"
    return 0
  fi
  local keyfile="/etc/apt/keyrings/dev-workstation-$provider.gpg"
  local listfile="/etc/apt/sources.list.d/dev-workstation-$provider.list"
  if [[ ! -f "$listfile" ]]; then
    command -v gpg >/dev/null 2>&1 || { warn "$provider requer gpg"; return 0; }
    log "Adicionando repositório APT oficial $provider (somente pacote ausente)"
    if ! curl -fsSL --max-time 25 "$keyurl" -o "$TMP_DIR/vendor-key-$provider"; then
      warn "$provider: chave indisponível"; return 0
    fi
    if ! gpg --dearmor < "$TMP_DIR/vendor-key-$provider" > "$TMP_DIR/vendor-key-$provider.gpg"; then
      warn "$provider: chave inválida"; return 0
    fi
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo install -m 0644 "$TMP_DIR/vendor-key-$provider.gpg" "$keyfile"
    printf 'deb [signed-by=%s] %s %s main\n' "$keyfile" "$repo_url" "$suite" > "$TMP_DIR/vendor-list-$provider"
    sudo install -m 0644 "$TMP_DIR/vendor-list-$provider" "$listfile"
    if ! sudo apt-get update; then
      warn "$provider: APT recusou repositório; revertendo os arquivos que adicionamos"
      sudo rm -f "$keyfile" "$listfile"
      sudo apt-get update || true
      return 0
    fi
    record systemfile "$listfile" ''
    record systemfile "$keyfile" ''
  fi
  optional_package "$pkg" "$executable"
}

setup_full_cli() {
  if [[ "$PKG" == brew ]]; then
    local p cmd
    for p in k9s lazydocker kubectx stern yq trivy tflint git-delta just gh \
             watchexec hyperfine atuin terraform ansible lazygit; do
      cmd="$p"; [[ "$p" == git-delta ]] && cmd=delta
      optional_package "$p" "$cmd"
    done
    optional_package postgresql@17 psql
    optional_package mysql-client mysql
    optional_package sqlite sqlite3
    return 0
  fi
  local spec p cmd
  for spec in 'gh:gh' 'git-delta:delta' 'just:just' 'hyperfine:hyperfine' \
              'watchexec:watchexec' 'kubectx:kubectx' 'ansible:ansible' \
              'postgresql-client:psql' 'sqlite3:sqlite3' 'lazygit:lazygit' \
              'k9s:k9s' 'lazydocker:lazydocker' 'stern:stern' 'trivy:trivy' \
              'tflint:tflint' 'terraform:terraform' 'atuin:atuin' 'yq:yq'; do
    p="${spec%%:*}"; cmd="${spec#*:}"
    # Evita instalar yq incompatível (Python) no Debian.
    if [[ "$p" == yq && "$PKG" == apt ]]; then continue; fi
    if ! command -v "$cmd" >/dev/null 2>&1; then
      case "$PKG" in
        apt) apt-cache show "$p" >/dev/null 2>&1 || continue;;
        dnf) dnf info "$p" >/dev/null 2>&1 || continue;;
        pacman) pacman -Si "$p" >/dev/null 2>&1 || continue;;
        zypper) : ;;
      esac
    fi
    optional_package "$p" "$cmd"
  done
  # Fallback para releases estáveis, apenas quando a API publicar digest.
  local arch_go='amd64' lazy_arch='x86_64'
  case "$ARCH" in aarch64|arm64) arch_go=arm64; lazy_arch=arm64;; esac
  github_verified derailed/k9s "^k9s_Linux_${arch_go}\\.tar\\.gz$" k9s tar.gz
  github_verified jesseduffield/lazydocker "^lazydocker_[0-9].*_Linux_${lazy_arch}\\.tar\\.gz$" lazydocker tar.gz
  github_verified stern/stern "^stern_[0-9].*_linux_${arch_go}\\.tar\\.gz$" stern tar.gz
  github_verified mikefarah/yq "^yq_linux_${arch_go}$" yq raw
  github_verified terraform-linters/tflint "^tflint_linux_${arch_go}\\.zip$" tflint zip
  local target='x86_64-unknown-linux-gnu'
  [[ "$arch_go" == arm64 ]] && target='aarch64-unknown-linux-gnu'
  github_verified atuinsh/atuin "^atuin-${target}\\.tar\\.gz$" atuin tar.gz
  github_verified casey/just "^just-.*-${target}\\.tar\\.gz$" just tar.gz
  github_verified sharkdp/hyperfine "^hyperfine-.*-${target}\\.tar\\.gz$" hyperfine tar.gz
  github_verified watchexec/watchexec "^watchexec-.*-${target}\\.tar\\.xz$" watchexec tar.xz
  github_verified dandavison/delta "^delta-.*-${target}\\.tar\\.gz$" delta tar.gz
  github_verified jesseduffield/lazygit "^lazygit_[0-9].*_Linux_${lazy_arch}\\.tar\\.gz$" lazygit tar.gz
  if [[ "$PKG" == apt ]]; then
    if [[ "$DISTRO" == debian || "$DISTRO" == ubuntu ]]; then
      local codename="${VERSION_CODENAME:-}"
      if [[ -n "$codename" ]]; then
        apt_vendor_repo hashicorp 'https://apt.releases.hashicorp.com/gpg' \
          'https://apt.releases.hashicorp.com' "$codename" terraform terraform
      fi
    fi
    apt_vendor_repo trivy 'https://aquasecurity.github.io/trivy-repo/deb/public.key' \
      'https://aquasecurity.github.io/trivy-repo/deb' generic trivy trivy
  fi
  if ! command -v kubens >/dev/null 2>&1 || ! command -v kubectx >/dev/null 2>&1; then
    local repo="$HOME/.local/opt/kubectx"
    clone_managed https://github.com/ahmetb/kubectx.git "$repo"
    for spec in kubectx kubens; do
      if [[ -f "$repo/$spec" && ! -e "$HOME/.local/bin/$spec" ]]; then
        ln -s "$repo/$spec" "$HOME/.local/bin/$spec"
        record link "$HOME/.local/bin/$spec" ''
      fi
    done
  fi
}

setup_font() {
  if [[ "$PLATFORM" == macos ]]; then
    package font-jetbrains-mono-nerd-font 'NERD-FONT-CHECK' cask
    warn 'Selecione JetBrainsMono Nerd Font nas preferências do seu terminal para usar ícones.'
    return 0
  fi
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | awk 'index(tolower($0), "jetbrainsmono nerd font") {found=1} END {exit !found}'; then
    ok 'JetBrainsMono Nerd Font já instalada'; return 0
  fi
  # Evita arquivo não verificado: releases Nerd Fonts geralmente usam checksums
  # separados e nem sempre têm SHA256 na API; nesse caso apenas informa.
  local meta url digest file
  meta="$(curl -fsSL --max-time 20 https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null || true)"
  url="$(printf '%s' "$meta" | jq -r '[.assets[] | select(.name == "JetBrainsMono.zip") | .browser_download_url] | first // empty' 2>/dev/null || true)"
  digest="$(printf '%s' "$meta" | jq -r '[.assets[] | select(.name == "JetBrainsMono.zip") | .digest] | first // empty' 2>/dev/null || true)"
  if [[ "$digest" != sha256:* ]]; then
    warn 'Nerd Font: release sem SHA256 na API. Baixe manualmente do projeto Nerd Fonts.'; return 0
  fi
  file="$TMP_DIR/JetBrainsMono.zip"
  curl -fsSL --max-time 90 "$url" -o "$file"
  sha256_verify "${digest#sha256:}" "$file" || die 'Nerd Font: checksum incorreto'
  mkdir -p "$font_dir"
  unzip -oq "$file" -d "$font_dir"
  record dir "$font_dir" ''
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$font_dir" || true
}


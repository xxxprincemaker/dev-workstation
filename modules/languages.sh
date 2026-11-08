# Language installers adapted from V7. Source from install.sh only.
sha256_verify() {
  local expected="$1" file="$2" actual=''
  case "$expected" in *[!0-9a-f]*|'') return 1;; esac
  [[ ${#expected} -eq 64 ]] || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  else die 'É necessário sha256sum ou shasum -a 256 para verificar downloads.'; fi
  [[ "$expected" == "$actual" ]]
}

setup_basics() {
  case "$PKG" in
    brew)
      package git git
      package git-lfs git-lfs
      for p in curl wget jq ripgrep fd fzf bat eza zoxide direnv shellcheck \
               tree-sitter-cli python@3.13 pipx gcc make pkgconf unzip; do
        # O sistema macOS já traz alguns utilitários; caso existam, preservar.
        case "$p" in python@3.13) package "$p" python3;;
          tree-sitter-cli) package "$p" tree-sitter;;
          pkgconf) package "$p" pkg-config;;
          *) optional_package "$p" "$p";;
        esac
      done;;
    apt)
      for p in ca-certificates curl wget gnupg git git-lfs openssh-client \
               build-essential make pkg-config unzip zip tar xz-utils jq \
               ripgrep shellcheck tree python3 python3-pip python3-venv \
               pipx; do optional_package "$p" ''; done
      # Pacotes com binários de nome diferente no Debian.
      optional_package fd-find fdfind
      optional_package bat batcat
      for p in fzf zoxide direnv; do optional_package "$p"; done
      mkdir -p "$HOME/.local/bin"
      if command -v fdfind >/dev/null 2>&1 && [[ ! -e "$HOME/.local/bin/fd" ]]; then
        ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"; record link "$HOME/.local/bin/fd" ''
      fi
      if command -v batcat >/dev/null 2>&1 && [[ ! -e "$HOME/.local/bin/bat" ]]; then
        ln -s "$(command -v batcat)" "$HOME/.local/bin/bat"; record link "$HOME/.local/bin/bat" ''
      fi;;
    dnf)
      for p in git git-lfs curl wget jq ripgrep fd-find fzf bat eza zoxide \
               direnv ShellCheck python3 python3-pip pipx gcc gcc-c++ make \
               pkgconf-pkg-config unzip tar gzip; do optional_package "$p" ''; done;;
    pacman)
      for p in git git-lfs curl wget jq ripgrep fd fzf bat eza zoxide \
               direnv shellcheck python python-pip python-pipx base-devel \
               unzip zip; do optional_package "$p" ''; done;;
    zypper)
      for p in git git-lfs curl wget jq ripgrep fd fzf bat eza zoxide \
               direnv ShellCheck python3 python3-pip pipx gcc gcc-c++ make \
               pkg-config unzip zip; do optional_package "$p" ''; done;;
  esac
  if command -v git >/dev/null 2>&1 && git lfs version >/dev/null 2>&1; then git lfs install --skip-repo || true; fi
}

# JDK LTS: macOS usa cask Adoptium; Linux usa artefato oficial da API Adoptium
# com hash SHA256 publicado. Não altera /usr/bin/java nem o JDK do sistema.
linux_temurin() {
  local major="$1" found='' arch_adoptium=''
  if [[ "$MODE" == update && ! -x "$DATA_DIR/jdks/temurin-$major/bin/java" ]]; then
    log "Temurin $major not owned as direct V8 installation; upgrade through existing package manager"
    return 0
  fi
  case "$ARCH" in x86_64|amd64) arch_adoptium=x64;; aarch64|arm64) arch_adoptium=aarch64;;
    *) warn "JDK Linux: arquitetura não suportada: $ARCH"; return 0;; esac
  local target="$DATA_DIR/jdks/temurin-$major" file="$TMP_DIR/temurin-$major.tar.gz"
  if [[ -x "$target/bin/java" ]] && [[ "$MODE" != update ]]; then
    ok "Temurin $major já instalado em $target"; return 0
  fi
  if [[ -n "$(command -v java 2>/dev/null || true)" ]] && java -version 2>&1 | grep -Eq "version \"?$major([.\"]|$)" && [[ ! -d "$target" ]]; then
    ok "Java $major presente fora da V7, preservado"; return 0
  fi
  command -v jq >/dev/null 2>&1 || { warn "JDK $major exige jq, indisponível"; return 0; }
  local metadata line semver url sha current=''
  metadata="$(curl -fsSL --max-time 25 "https://api.adoptium.net/v3/assets/latest/$major/hotspot?architecture=$arch_adoptium&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os=linux&vendor=eclipse" 2>/dev/null || true)"
  if [[ -z "$metadata" ]]; then warn "Temurin $major: API indisponível; preservando o existente"; return 0; fi
  line="$(printf '%s' "$metadata" | jq -r '[.[] | select(.binary.package.link and .binary.package.checksum) | [.version.semver, .binary.package.link, .binary.package.checksum] | @tsv] | first // empty' 2>/dev/null || true)"
  [[ -n "$line" ]] || { warn "Temurin $major: metadados sem arquivo/checksum; ignorado"; return 0; }
  IFS=$'\t' read -r semver url sha <<EOF
$line
EOF
  [[ "$url" == https://* && "$sha" =~ ^[0-9a-f]{64}$ ]] || { warn 'Temurin: URL ou SHA256 inválidos'; return 0; }
  current="$("$target/bin/java" -version 2>&1 | awk 'NR==1 {print $3}' | tr -d '"' || true)"
  if [[ -n "$current" && "$MODE" == update ]]; then
    log "Temurin $major: instalada=$current | disponível=$semver"
    if ! semver_newer "$current" "$semver"; then ok 'Temurin mantido (sem downgrade)'; return 0; fi
    if ! ((YES_UPDATES)) && ! answer_yes "Upgrade Temurin $major to $semver?"; then return 0; fi
  fi
  ((DRY_RUN)) && { log "[PRÉVIA] baixar e instalar Temurin $semver (SHA256)"; return 0; }
  curl -fsSL --retry 2 --max-time 120 "$url" -o "$file"
  sha256_verify "$sha" "$file" || die "Temurin $major: SHA256 incorreto. Instalação bloqueada."
  local newdir="$TMP_DIR/temurin-extract-$major" backup=''
  mkdir -p "$newdir" "$(dirname "$target")"
  tar -xzf "$file" -C "$newdir" --strip-components=1
  [[ -x "$newdir/bin/java" ]] || die 'Temurin baixado não contém bin/java.'
  if [[ -e "$target" ]]; then
    backup="$target.v7-backup-$(date +%Y%m%d-%H%M%S)-$$"
    mv "$target" "$backup"
    warn "Versão anterior preservada: $backup"
  else
    record dir "$target" ''
  fi
  mv "$newdir" "$target"
  ok "Temurin $major instalado: $semver"
}

setup_java() {
  if [[ "$PLATFORM" == macos ]]; then
    if [[ "$MODE" == update ]] && pkg_installed 'temurin@25' cask; then
      package 'temurin@25' 'JDK-25-not-present' cask
    elif /usr/libexec/java_home -v 25 >/dev/null 2>&1; then ok 'Java 25 existente, preservado'
    else package 'temurin@25' 'JDK-25-not-present' cask; fi
    if ((JAVA21)); then
      if [[ "$MODE" == update ]] && pkg_installed 'temurin@21' cask; then
        package 'temurin@21' 'JDK-21-not-present' cask
      elif /usr/libexec/java_home -v 21 >/dev/null 2>&1; then ok 'Java 21 existente, preservado'
      else package 'temurin@21' 'JDK-21-not-present' cask; fi
    fi
    local jhome=''
    jhome="$(/usr/libexec/java_home -v 25 2>/dev/null || true)"
    if [[ -n "$jhome" ]]; then export JAVA_HOME="$jhome"; export PATH="$JAVA_HOME/bin:$PATH"; fi
  else
    linux_temurin 25
    if ((JAVA21)); then linux_temurin 21; fi
    if [[ -x "$DATA_DIR/jdks/temurin-25/bin/java" ]]; then
      export JAVA_HOME="$DATA_DIR/jdks/temurin-25"
      export PATH="$JAVA_HOME/bin:$PATH"
    fi
  fi
}

setup_sdkman() {
  if [[ "$MODE" == update && ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then warn 'SDKMAN not installed; skipped in update mode'; return 0; fi
  if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log 'SDKMAN ausente: instalar inicializador oficial (não como root)'
    curl -fsSL --max-time 30 'https://get.sdkman.io?ci=true&rcupdate=false' -o "$TMP_DIR/sdkman-installer.sh"
    SDKMAN_DIR="$SDKMAN_DIR" bash "$TMP_DIR/sdkman-installer.sh"
    [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && record sdkman "$SDKMAN_DIR" ''
  else ok 'SDKMAN já instalado, preservado'; fi
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || { warn 'SDKMAN não inicializou'; return 0; }
  if command -v mvn >/dev/null 2>&1 || [[ -x "$SDKMAN_DIR/candidates/maven/current/bin/mvn" ]]; then ok "Maven já instalado"
  else
    log 'SDKMAN: instalando Maven'
    if run_sdk install maven; then record sdk_candidate maven "$SDKMAN_DIR/candidates/maven"; else warn 'Maven: SDKMAN falhou'; fi
  fi
  if command -v gradle >/dev/null 2>&1 || [[ -x "$SDKMAN_DIR/candidates/gradle/current/bin/gradle" ]]; then ok "Gradle já instalado"
  else
    log 'SDKMAN: instalando Gradle'
    if run_sdk install gradle; then record sdk_candidate gradle "$SDKMAN_DIR/candidates/gradle"; else warn 'Gradle: SDKMAN falhou'; fi
  fi
  if [[ "$MODE" == update ]]; then
    warn 'Atualizações Maven/Gradle pelo SDKMAN não serão feitas automaticamente; consulte `sdk list` e `sdk upgrade`.'
  fi
}

setup_node() {
  if [[ "$MODE" == update && ! -s "$NVM_DIR/nvm.sh" ]]; then warn 'NVM absent; skipped in update mode'; return 0; fi
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log 'NVM ausente: instalando versão estável fixada do instalador oficial.'
    curl -fsSL --max-time 30 'https://raw.githubusercontent.com/nvm-sh/nvm/v0.41.0/install.sh' -o "$TMP_DIR/nvm-installer.sh"
    PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash "$TMP_DIR/nvm-installer.sh"
    [[ -s "$NVM_DIR/nvm.sh" ]] && record nvm "$NVM_DIR" ''
  else ok 'NVM instalado, preservado'; fi
  load_nvm
  if ! command -v nvm >/dev/null 2>&1; then warn 'NVM indisponível'; return 0; fi
  if [[ "$MODE" == update ]]; then
    local installed_nvm='' latest_nvm=''
    installed_nvm="$(nvm --version 2>/dev/null || true)"
    latest_nvm="$(latest_git_tag nvm-sh/nvm)"
    if [[ "$latest_nvm" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] && semver_newer "$installed_nvm" "$latest_nvm"; then
      log "NVM: instalado=$installed_nvm | disponível=$latest_nvm"
      if ((YES_UPDATES)) || answer_yes "Upgrade NVM to $latest_nvm?"; then
        curl -fsSL --max-time 30 "https://raw.githubusercontent.com/nvm-sh/nvm/$latest_nvm/install.sh" -o "$TMP_DIR/nvm-updater.sh"
        PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash "$TMP_DIR/nvm-updater.sh"
        load_nvm
      fi
    fi
  fi
  local node_local=''
  node_local="$(nvm version 'lts/*' 2>/dev/null || true)"
  if [[ "$node_local" != v* && "$MODE" == update ]]; then
    warn 'Node LTS missing; skipped in update mode'; return 0
  elif [[ "$node_local" != v* ]]; then
    nvm install --lts && nvm alias default 'lts/*'
  else
    ok "Node LTS via NVM: $node_local"
    if [[ "$MODE" == update ]]; then
      local remote_node=''
      remote_node="$(nvm ls-remote --lts 2>/dev/null | awk '/v[0-9]+\.[0-9]+\.[0-9]+/ {n=$1} END {print n}' || true)"
      if [[ -n "$remote_node" ]] && semver_newer "$node_local" "$remote_node"; then
        log "Node LTS: instalada=$node_local | disponível=$remote_node"
        if ((YES_UPDATES)) || answer_yes "Install Node LTS $remote_node and make it the NVM default?"; then
          nvm install "$remote_node" && nvm alias default "$remote_node"
        fi
      fi
    fi
  fi
  nvm use --silent 'lts/*' || true
  if ! command -v corepack >/dev/null 2>&1 && [[ "$MODE" != update ]]; then
    npm install --global corepack || warn 'Corepack não instalado'
  fi
  if command -v corepack >/dev/null 2>&1; then
    if [[ "$MODE" == update ]]; then
      local current_corepack='' latest_corepack=''
      current_corepack="$(corepack --version 2>/dev/null || true)"
      latest_corepack="$(npm view corepack version 2>/dev/null || true)"
      if [[ -n "$latest_corepack" ]] && semver_newer "$current_corepack" "$latest_corepack"; then
        log "Corepack: instalado=$current_corepack | disponível=$latest_corepack"
        if ((YES_UPDATES)) || answer_yes "Upgrade Corepack to $latest_corepack?"; then
          npm install --global "corepack@$latest_corepack" || warn 'Falha ao atualizar Corepack'
        fi
      fi
    fi
    corepack enable || warn 'Corepack enable indisponível'
    for p in pnpm yarn; do
      if ! command -v "$p" >/dev/null 2>&1 && [[ "$MODE" != update ]]; then
        if [[ "$p" == pnpm ]]; then corepack install --global pnpm@latest || true
        else corepack install --global yarn@stable || true; fi
      else ok "$p já disponível"; fi
    done
  fi
}

setup_go() {
  if [[ "$MODE" == update && "$PLATFORM" == linux && ! -x "$DATA_DIR/go/current/bin/go" ]] && ! command -v go >/dev/null 2>&1; then
    log 'Go is missing; use --install to add it.'; return 0
  fi
  if [[ "$PLATFORM" == macos ]]; then package go go; return; fi
  if command -v go >/dev/null 2>&1 && [[ "$MODE" != update ]]; then
    ok "Go funcional: $(go version); preservado"; return 0
  fi
  if command -v go >/dev/null 2>&1 && ! owned dir "$DATA_DIR/go/current"; then
    ok "Go existente fora da V7: $(go version); não será substituído"
    if [[ "$MODE" == update ]]; then
      local go_pkg=''
      case "$PKG" in apt) go_pkg=golang-go;; dnf) go_pkg=golang;; pacman|zypper) go_pkg=go;; esac
      if [[ -n "$go_pkg" ]] && pkg_installed "$go_pkg"; then
        package "$go_pkg" go
      else warn 'Go externo: versão gerenciada fora deste instalador; consulte seu gerenciador de origem.'; fi
    fi
    return 0
  fi
  command -v jq >/dev/null 2>&1 || { warn 'Instalação Go exige jq'; return 0; }
  local arch_go='' metadata entry version filename sha target="$DATA_DIR/go/current" current=''
  case "$ARCH" in x86_64|amd64) arch_go=amd64;; aarch64|arm64) arch_go=arm64;;
    *) warn "Go: arquitetura Linux não suportada: $ARCH"; return 0;; esac
  metadata="$(curl -fsSL --max-time 25 'https://go.dev/dl/?mode=json' 2>/dev/null || true)"
  [[ -n "$metadata" ]] || { warn 'Go: API de versões indisponível'; return 0; }
  entry="$(printf '%s' "$metadata" | jq -r --arg a "$arch_go" '[.[] | select(.stable == true) | . as $r | .files[] | select(.os == "linux" and .arch == $a and .kind == "archive") | [$r.version,.filename,.sha256] | @tsv] | first // empty' || true)"
  [[ -n "$entry" ]] || { warn 'Go: metadados de release indisponíveis'; return 0; }
  IFS=$'\t' read -r version filename sha <<EOF
$entry
EOF
  [[ "$filename" == "${version}.linux-${arch_go}.tar.gz" && "$sha" =~ ^[0-9a-f]{64}$ ]] || die 'Go: metadados inválidos'
  if [[ -x "$target/bin/go" ]]; then current="$("$target/bin/go" version || true)"; fi
  if [[ -n "$current" ]]; then
    if [[ "$current" == *"$version"* ]]; then ok "Go atualizado: $current"; return 0; fi
    local current_ver=''
    current_ver="$(printf '%s' "$current" | awk '{print $3}')"
    if ! semver_newer "$current_ver" "$version"; then
      ok "Go existente não é mais antigo ($current_ver); sem downgrade"; return 0
    fi
    if ! ((YES_UPDATES)) && ! answer_yes "Upgrade Go from $current to $version?"; then return 0; fi
  fi
  ((DRY_RUN)) && { log "[PRÉVIA] instalar $version verificado"; return 0; }
  local tarball="$TMP_DIR/$filename" unpack="$TMP_DIR/go-unpack" backup=''
  curl -fsSL --max-time 120 --retry 2 "https://go.dev/dl/$filename" -o "$tarball"
  sha256_verify "$sha" "$tarball" || die 'Go: falha SHA256'
  mkdir -p "$unpack" "$(dirname "$target")"
  tar -xzf "$tarball" -C "$unpack"
  [[ -x "$unpack/go/bin/go" ]] || die 'Arquivo Go não contém bin/go.'
  if [[ -e "$target" ]]; then
    backup="$target.v7-backup-$(date +%Y%m%d-%H%M%S)-$$"; mv "$target" "$backup"
    warn "Go anterior preservado: $backup"
  else record dir "$target" ''; fi
  mv "$unpack/go" "$target"
  if [[ ! -e "$HOME/.local/bin/go" ]]; then
    ln -s "$target/bin/go" "$HOME/.local/bin/go"; record link "$HOME/.local/bin/go" ''
  fi
  ok "Go instalado: $version"
}

setup_go_tools() {
  command -v go >/dev/null 2>&1 || { warn 'Go não encontrado; pulando gopls/goimports'; return 0; }
  mkdir -p "$HOME/go/bin"
  local tool module
  for tool in gopls goimports; do
    if command -v "$tool" >/dev/null 2>&1; then ok "$tool already installed"; continue; fi
    [[ "$MODE" == update ]] && continue
    case "$tool" in
      gopls) module=golang.org/x/tools/gopls@latest;;
      goimports) module=golang.org/x/tools/cmd/goimports@latest;;
    esac
    if go install "$module"; then
      if [[ -f "$HOME/go/bin/$tool" ]]; then record binary "$HOME/go/bin/$tool" ''; fi
    else warn "Não foi possível instalar $tool"; fi
  done
}
setup_docker() {
  if [[ "$PLATFORM" == macos ]]; then
    if pkg_installed docker-desktop cask && [[ "$MODE" == update ]]; then
      package docker-desktop docker-desktop-not-found cask
    elif [[ -d /Applications/Docker.app ]] || pkg_installed docker-desktop cask; then
      ok 'Docker Desktop já instalado; não reinstalado'
    else
      log 'Docker Desktop será instalado como cask; o usuário deve abrir o aplicativo e aceitar os termos.'
      package docker-desktop docker-desktop-not-found cask
    fi
    if command -v docker >/dev/null 2>&1; then
      if docker compose version >/dev/null 2>&1; then ok 'Docker Compose v2 disponível'
      else warn 'Compose ausente: abra/inicie Docker Desktop antes de reavaliar'; fi
    fi
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    ok "Docker existente: $(docker --version); não será substituído por outro daemon"
    if [[ "$MODE" == update ]]; then
      case "$PKG" in
        apt)
          for p in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
            if pkg_installed "$p"; then package "$p" ''; fi
          done;;
        dnf) if pkg_installed moby-engine; then package moby-engine docker; fi;;
        pacman) warn 'Docker no Arch: execute atualização completa sudo pacman -Syu para evitar partial upgrade';;
        zypper) if pkg_installed docker; then package docker docker; fi;;
      esac
    fi
    if docker compose version >/dev/null 2>&1; then ok "Compose: $(docker compose version)"
    else
      warn 'Docker Compose v2 não encontrado no CLI atual.'
      case "$PKG" in
        apt) optional_package docker-compose-plugin docker-compose-plugin;;
        dnf) optional_package docker-compose-plugin docker-compose-plugin;;
        pacman) optional_package docker-compose docker-compose;;
        zypper) optional_package docker-compose docker-compose;;
      esac
    fi
    return 0
  fi
  case "$PKG" in
    apt)
      # Debian/Ubuntu: repo oficial Docker, sem remover docker.io/podman/docker de terceiros.
      case "$DISTRO" in
        debian|ubuntu) :;;
        *) warn "Derivado '$DISTRO': use Docker oficial da sua distribuição; não adicionamos repo de outra distro automaticamente."; optional_package docker.io docker; return 0;;
      esac
      command -v gpg >/dev/null 2>&1 || { warn 'Docker: gnupg ausente'; return 0; }
      local source_path='/etc/apt/sources.list.d/dev-workstation-docker.sources'
      local key_path='/etc/apt/keyrings/dev-workstation-docker.asc'
      local codename arch_apt url
      codename="${VERSION_CODENAME:-}"
      arch_apt="$(dpkg --print-architecture)"
      [[ -n "$codename" ]] || { warn 'Docker: codename do APT não detectado'; return 0; }
      url="https://download.docker.com/linux/$DISTRO"
      if [[ ! -f "$source_path" ]]; then
        curl -fsSL --max-time 25 "$url/gpg" -o "$TMP_DIR/docker.asc"
        sudo install -d -m 0755 /etc/apt/keyrings
        sudo install -m 0644 "$TMP_DIR/docker.asc" "$key_path"
        cat > "$TMP_DIR/docker.sources" <<EOF
Types: deb
URIs: $url
Suites: $codename
Components: stable
Architectures: $arch_apt
Signed-By: $key_path
EOF
        sudo install -m 0644 "$TMP_DIR/docker.sources" "$source_path"
        record systemfile "$source_path" ''
        record systemfile "$key_path" ''
        sudo apt-get update || { warn 'Repo Docker incompatível. Arquivos gerenciados não serão usados.'; return 0; }
      fi
      for p in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do optional_package "$p" ''; done;;
    dnf)
      # Utiliza repositórios da distribuição; não mistura pacotes docker-ce com podman.
      optional_package moby-engine docker
      optional_package docker-compose-plugin docker-compose-plugin;;
    pacman)
      optional_package docker docker
      optional_package docker-compose docker-compose
      optional_package docker-buildx docker-buildx;;
    zypper)
      optional_package docker docker
      optional_package docker-compose docker-compose;;
  esac
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    if confirm_risk 'Enable and start Docker service (systemctl)?'; then
      sudo systemctl enable --now docker || warn 'Docker instalado; serviço não iniciado'
    fi
  fi
  if command -v getent >/dev/null 2>&1 && getent group docker >/dev/null 2>&1; then
    if ! id -nG | tr ' ' '\n' | grep -qx docker; then
      warn 'Grupo docker concede privilégios equivalentes a root.'
      if confirm_risk 'Add your user to the docker group? This grants root-equivalent privileges.'; then
        sudo usermod -aG docker "$(id -un)"
        record group docker "$(id -un)"
      fi
    fi
  fi
}


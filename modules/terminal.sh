# Zsh/tmux/Neovim configs, preserving V7 layout for upgrades.
# Configurações mantidas da V6 (tmux Pro / LazyVim / Spaceship).
generate_tmux_help_txt() {
cat > "$TMP_DIR/tmux-help.txt" <<'V7_TMUX_HELP_TXT'
TMUX PRO — QUICK REFERENCE                    Prefix: Ctrl+A
=======================================================================
NAVIGATION                         LAYOUT
  Ctrl+A s     Session picker         Ctrl+A |     Split side by side
  Ctrl+A w     Window picker          Ctrl+A -     Split top/bottom
  Ctrl+A Tab   Previous window        Ctrl+A c     New window
  Ctrl+A 1-9   Jump to window         Ctrl+A z     Zoom/unzoom pane
  Ctrl+A n/p   Next/prev window       Ctrl+A ,     Rename window
  Ctrl+A h/j/k/l  Move between panes  Ctrl+A $     Rename session
  Ctrl+A arrows Move between panes    Ctrl+A x     Close pane (asks)

TOOLS (POPUPS)                     COPY AND UTILITIES
  Ctrl+A g     LazyGit                Ctrl+A [     Enter copy mode
  Ctrl+A D     Lazydocker             v           Select (copy mode)
  Ctrl+A K     K9s                    y           Copy (copy mode)
  Ctrl+A ?     This help              Ctrl+A d     Detach session
  Ctrl+A r     Reload tmux config     Ctrl+A I     Install TPM plugins
  Ctrl+A U     Update TPM plugins     Ctrl+A Ctrl+A  Send literal Ctrl+A

TIPS
  • Bottom status bar shows session, numbered windows and active window.
  • PREFIX ACTIVE highlights when Ctrl+A is awaiting the next key.
  • Click windows to switch; drag separators to resize panes.
  • SessionX provides fuzzy session search when installed; otherwise native.
  • Ctrl+h/j/k/l switches between Neovim splits and tmux panes when enabled.
  • Detach keeps your session running: Ctrl+A d.
  • Reattach: tmux attach -t your-session
  • Recommended shortcut: t (tmux new-session -A -s main)
V7_TMUX_HELP_TXT
}

generate_tmux_tools_sh() {
cat > "$TMP_DIR/tmux-tools.sh" <<'V7_TMUX_TOOLS_SH'
#!/usr/bin/env bash
# dev-bootstrap-linux: tmux-tools-managed
set -euo pipefail
case "${1:-}" in
  help)
    file="$HOME/.config/dev-bootstrap/tmux-help.txt"
    if command -v less >/dev/null 2>&1; then exec less -R "$file"; fi
    cat "$file"
    printf '\nPress Enter to close...'
    IFS= read -r _ || true
    exit 0
    ;;
  lazygit|lazydocker|k9s) app="$1" ;;
  *) printf 'Unknown tmux tool: %s\n' "${1:-}" >&2; exit 2 ;;
esac
if ! command -v "$app" >/dev/null 2>&1; then
  printf '%s not installed. Run --install --full-dev to add it.\n' "$app"
  printf 'Press Enter to close...'
  IFS= read -r _ || true
  exit 0
fi
exec "$app"
V7_TMUX_TOOLS_SH
}

generate_tmux_ui_conf() {
cat > "$TMP_DIR/tmux-ui.conf" <<'V7_TMUX_UI_CONF'
# dev-bootstrap-linux: tmux-ui-managed
# UX inspirado em Catppuccin Mocha, renderizado pelo tmux nativo.
# Prefixo + s: SessionX via TPM se instalado; fallback tmux choose-tree.
set -g mouse on
set -g focus-events on
set -g history-limit 100000
set -g escape-time 10
set -g status-keys vi
setw -g mode-keys vi
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal 'tmux-256color'
set -as terminal-overrides ',*:Tc'
set -g set-clipboard on
set -g status-position bottom
set -g status-interval 5
set -g status-justify left
set -g status-style 'bg=#1e1e2e,fg=#cdd6f4'
set -g status-left-length 36
set -g status-right-length 85
set -g status-left '#[bg=#cba6f7,fg=#11111b,bold] 󰆍 #S #[bg=#1e1e2e,fg=#cba6f7]#[default] '
set -g status-right '#[bg=#313244,fg=#f9e2af,bold] #{?client_prefix,● PREFIX ACTIVE,Ctrl+A ? help} #[bg=#313244,fg=#a6e3a1] #{pane_current_command} #[fg=#89b4fa] %a %d/%m %H:%M '
setw -g window-status-separator ' '
setw -g window-status-format '#[bg=#313244,fg=#bac2de] #I:#W#F #[default]'
setw -g window-status-current-format '#[bg=#89b4fa,fg=#11111b,bold] #I:#W#{?window_zoomed_flag, ,} #[default]'
setw -g window-status-activity-style 'bg=#313244,fg=#f9e2af'
setw -g window-status-bell-style 'bg=#313244,fg=#f38ba8'
set -g message-style 'bg=#cba6f7,fg=#11111b,bold'
set -g message-command-style 'bg=#313244,fg=#cdd6f4'
set -g mode-style 'bg=#cba6f7,fg=#11111b'
set -g pane-border-style 'fg=#45475a'
set -g pane-active-border-style 'fg=#89b4fa'
set -g pane-border-status top
set -g pane-border-format ' #[fg=#89b4fa]#{pane_index} #[fg=#a6adc8]#{pane_current_command} #[default]'
setw -g automatic-rename on
setw -g allow-rename off
set -g monitor-activity on
set -g visual-activity off
set -g visual-bell off

# Atalhos de movimentacao: navegar sem acertar setinhas pequenas.
bind r source-file ~/.tmux.conf \; display-message 'tmux config reloaded'
bind | split-window -h -c '#{pane_current_path}'
bind - split-window -v -c '#{pane_current_path}'
bind c new-window -c '#{pane_current_path}'
bind -r h select-pane -L
bind -r j select-pane -D
bind -r k select-pane -U
bind -r l select-pane -R
bind -r Left select-pane -L
bind -r Down select-pane -D
bind -r Up select-pane -U
bind -r Right select-pane -R
bind -r n next-window
bind -r p previous-window
bind Tab last-window
bind s choose-tree -s
bind w choose-tree -w
bind ? display-popup -E -w 80% -h 80% 'bash ~/.config/dev-bootstrap/tmux-tools.sh help'
bind g display-popup -E -d '#{pane_current_path}' -w 90% -h 85% 'bash ~/.config/dev-bootstrap/tmux-tools.sh lazygit'
bind D display-popup -E -d '#{pane_current_path}' -w 90% -h 85% 'bash ~/.config/dev-bootstrap/tmux-tools.sh lazydocker'
bind K display-popup -E -d '#{pane_current_path}' -w 90% -h 85% 'bash ~/.config/dev-bootstrap/tmux-tools.sh k9s'
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi C-v send -X rectangle-toggle
V7_TMUX_UI_CONF
}

generate_dev_tmux_conf() {
cat > "$TMP_DIR/dev-tmux.conf" <<'V7_DEV_TMUX_CONF'
# dev-bootstrap-linux: tmux-managed
# Prefixo Ctrl+A. Ajuda visual: Ctrl+A, depois ?.
set -g prefix C-a
unbind C-b
bind C-a send-prefix
source-file ~/.config/dev-bootstrap/tmux-ui.conf
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @resurrect-capture-pane-contents 'off'
# O perfil full-dev pode existir mesmo que esta execucao seja apenas --tmux-only.
if-shell 'test -f ~/.config/dev-bootstrap/tmux-full.conf' 'source-file ~/.config/dev-bootstrap/tmux-full.conf'
# Mantenha continuum por ultimo na lista de plugins; o TPM adiciona autosave.
run '~/.tmux/plugins/tpm/tpm'
# Customizacoes do usuario sobrevivem as atualizacoes do bootstrap.
if-shell 'test -f ~/.config/dev-bootstrap/tmux-custom.conf' 'source-file ~/.config/dev-bootstrap/tmux-custom.conf'
V7_DEV_TMUX_CONF
}

generate_tmux_full_conf() {
cat > "$TMP_DIR/tmux-full.conf" <<'V7_TMUX_FULL_CONF'
# dev-bootstrap-linux: tmux-full-managed
# Plugin tmux-fzf e SessionX: Ctrl+A s abre fuzzy de sessoes.
# Fallback permanece o choose-tree nativo ate o plugin ficar disponivel.
set -g @sessionx-bind 's'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'sainnhe/tmux-fzf'
set -g @plugin 'omerxx/tmux-sessionx'
V7_TMUX_FULL_CONF
}

generate_dev_markdown_lua() {
cat > "$TMP_DIR/dev-markdown.lua" <<'V7_DEV_MARKDOWN_LUA'
-- dev-bootstrap-linux: markdown-managed
-- O extra lazyvim.plugins.extras.lang.markdown deve estar em lazyvim.json.
-- Neovim: renderiza diretamente (sem browser) e permite preview externo.
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      enabled = true,
      render_modes = { "n", "c", "t" }, -- modo insert mostra o Markdown bruto
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        width = "full",
      },
      checkbox = { enabled = true },
      code = { sign = false, width = "block", right_pad = 1 },
      pipe_table = { enabled = true, preset = "round", wrap = true },
      bullet = { icons = { "●", "○", "◆", "◇" } },
    },
    keys = {
      { "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Markdown: alternar renderizacao" },
      { "<leader>ms", "<cmd>RenderMarkdown preview<cr>", ft = "markdown", desc = "Markdown: leitura lado a lado" },
    },
    init = function()
      local group = vim.api.nvim_create_augroup("dev_bootstrap_markdown_reading", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "markdown", "markdown.mdx" },
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.showbreak = "↪ "
        end,
      })
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    -- O extra oficial faz o build do servidor e define :MarkdownPreviewToggle.
    keys = {
      { "<leader>mb", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown: preview no navegador" },
    },
  },
}
V7_DEV_MARKDOWN_LUA
}

generate_dev_bootstrap_lua() {
cat > "$TMP_DIR/dev-bootstrap.lua" <<'V7_DEV_BOOTSTRAP_LUA'
-- dev-bootstrap-linux: lazyvim-managed
-- Extras sao registrados em lazyvim.json, ANTES dos plugins do usuario.
-- Assim evitamos os avisos de ordem incorreta de import do LazyVim.
return {
  { "christoomey/vim-tmux-navigator", lazy = false },
}
V7_DEV_BOOTSTRAP_LUA
}

generate_full_dev_zsh() {
cat > "$TMP_DIR/full-dev.zsh" <<'V7_FULL_DEV_ZSH'
# dev-bootstrap-linux: zsh-full-managed
# Atuin: historico local; sincronizacao remota requer opt-in por login/registro.
# Ctrl-R passa ao Atuin; as setas continuam com history-substring-search.
if (( $+commands[atuin] )); then
  eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
fi
V7_FULL_DEV_ZSH
}

generate_dev_spaceshiprc_zsh() {
cat > "$TMP_DIR/dev-spaceshiprc.zsh" <<'V7_DEV_SPACESHIPRC_ZSH'
# dev-bootstrap-linux: spaceship-managed
SPACESHIP_PROMPT_ORDER=(user dir git node golang java docker kubectl exec_time line_sep exit_code char)
SPACESHIP_USER_SHOW=always
SPACESHIP_HOST_SHOW=false
SPACESHIP_DIR_TRUNC=3
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_PROMPT_SEPARATE_LINE=true
SPACESHIP_GIT_STATUS_SHOW=true
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_ELAPSED=3
SPACESHIP_KUBECTL_SHOW=true
SPACESHIP_KUBECTL_VERSION_SHOW=false
SPACESHIP_NODE_SHOW=true
SPACESHIP_GOLANG_SHOW=true
SPACESHIP_JAVA_SHOW=true
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_RPROMPT_ORDER=()
V7_DEV_SPACESHIPRC_ZSH
}

generate_dev_terminal_zsh() {
cat > "$TMP_DIR/dev-terminal.zsh" <<'V7_DEV_TERMINAL_ZSH'
# dev-bootstrap-linux: terminal-extras-managed
# Somente para Zsh interativo. Personalizacoes: ~/.config/dev-bootstrap/custom.zsh
[[ -o interactive ]] || return 0
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS SHARE_HISTORY
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
bindkey -e
if (( $+functions[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
fi
# Seletores difusos, navegacao por projetos e direnv sem auto-aprovar .envrc.
if (( $+commands[zoxide] )); then eval "$(zoxide init zsh)"; fi
if (( $+commands[direnv] )); then eval "$(direnv hook zsh)"; fi
if (( $+commands[nvim] )); then export EDITOR=nvim VISUAL=nvim; fi
# Atalhos de baixo risco; sem aliases que sobrescrevam comandos existentes.
(( $+commands[eza] )) && alias ll='eza -lah --group-directories-first --git' || alias ll='ls -lah --color=auto'
(( $+commands[bat] )) && alias catp='bat --paging=never'
(( $+commands[rg] )) && alias search='rg --hidden --glob "!.git"'
(( $+commands[kubectl] )) && alias k='kubectl'
(( $+commands[docker] )) && alias d='docker'
(( $+commands[tmux] )) && alias t='tmux new-session -A -s main'
alias ..='cd ..'
alias ...='cd ../..'
# O perfil full-dev e modular; pode ser instalado posteriormente e nao sera removido
# por um --install sem --full-dev.
[[ -f "$HOME/.config/dev-bootstrap/full-dev.zsh" ]] && source "$HOME/.config/dev-bootstrap/full-dev.zsh"
[[ -f "$HOME/.config/dev-bootstrap/custom.zsh" ]] && source "$HOME/.config/dev-bootstrap/custom.zsh"
V7_DEV_TERMINAL_ZSH
}

generate_dev_zshrc() {
cat > "$TMP_DIR/dev-zshrc" <<'V7_DEV_ZSHRC'
# dev-bootstrap-linux: terminal-managed
# Arquivo gerenciado; personalizacoes devem ir em ~/.config/dev-bootstrap/custom.zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="spaceship"
zstyle ':omz:update' mode disabled # atualizacoes do Oh My Zsh devem ser intencionais
plugins=(git sudo colored-man-pages extract command-not-found fzf
  docker docker-compose kubectl helm golang mvn gradle npm nvm
  zsh-autosuggestions zsh-completions zsh-history-substring-search)
# fzf-tab e carregado apenas quando instalado; syntax-highlighting fica por ultimo.
[[ -d "$ZSH/custom/plugins/fzf-tab" ]] && plugins+=(fzf-tab)
plugins+=(zsh-syntax-highlighting)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.config/dev-bootstrap/env.sh" ]] && source "$HOME/.config/dev-bootstrap/env.sh"
[[ -f "$HOME/.config/dev-bootstrap/terminal.zsh" ]] && source "$HOME/.config/dev-bootstrap/terminal.zsh"
V7_DEV_ZSHRC
}


append_managed_line() {
  local target="$1" marker="$2" content="$3" backup=''
  if [[ -f "$target" ]] && grep -Fq "$marker" "$target"; then return 0; fi
  [[ ! -L "$target" ]] || { warn "Não alteramos symlink de dotfile: $target"; return 0; }
  if [[ -e "$target" ]]; then
    if ! owned backup "$target" && ! owned created "$target"; then
      backup="$target.dev-workstation-v7.bak-$(date +%Y%m%d-%H%M%S)-$$"
      cp -p "$target" "$backup"
      record backup "$target" "$backup"
    fi
  else record created "$target" ''; fi
  printf '\n%s\n%s\n' "$marker" "$content" >> "$target"
  ok "Bloco V7 adicionado: $target"
}

setup_terminal_deps() {
  if [[ "$PKG" == brew ]]; then
    for p in zsh tmux fzf ripgrep fd bat eza zoxide direnv btop lazygit; do
      optional_package "$p"
    done
  else
    local p
    case "$PKG" in
      apt)
        for p in zsh tmux fzf ripgrep fd-find bat direnv btop; do optional_package "$p" ''; done
        for p in eza zoxide lazygit; do
          if apt-cache show "$p" >/dev/null 2>&1; then optional_package "$p"; else warn "$p indisponível neste APT; preservado"; fi
        done;;
      dnf)
        for p in zsh tmux fzf ripgrep fd-find bat eza zoxide direnv btop lazygit; do optional_package "$p" ''; done;;
      pacman)
        for p in zsh tmux fzf ripgrep fd bat eza zoxide direnv btop lazygit; do optional_package "$p" ''; done;;
      zypper)
        for p in zsh tmux fzf ripgrep fd bat eza zoxide direnv btop lazygit; do optional_package "$p" ''; done;;
    esac
  fi
}

setup_shell_env() {
  local envfile="$CONFIG_DIR/env.sh"
  cat > "$TMP_DIR/v7-env.sh" <<'ENVFILE'
# dev-workstation-v7: env-managed
# Carregado no shell do usuário; não adiciona sudo nem executa downloads.
export PATH="$HOME/.local/bin:$HOME/go/bin:$HOME/.atuin/bin:$PATH"
if [ "$(uname -s)" = Darwin ]; then
  if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)";
  elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
  if [ -x /usr/libexec/java_home ]; then
    _dev_java="$(/usr/libexec/java_home -v 25 2>/dev/null || true)"
    if [ -n "$_dev_java" ]; then export JAVA_HOME="$_dev_java"; export PATH="$JAVA_HOME/bin:$PATH"; fi
    unset _dev_java
  fi
else
  if [ -x "$HOME/.local/share/dev-workstation/jdks/temurin-25/bin/java" ]; then
    export JAVA_HOME="$HOME/.local/share/dev-workstation/jdks/temurin-25"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  if [ -x "$HOME/.local/share/dev-workstation/go/current/bin/go" ]; then
    export PATH="$HOME/.local/share/dev-workstation/go/current/bin:$PATH"
  fi
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
[ -f "$HOME/.config/dev-bootstrap/custom.sh" ] && . "$HOME/.config/dev-bootstrap/custom.sh"
ENVFILE
  write_owned "$envfile" "$TMP_DIR/v7-env.sh" '# dev-workstation-v7: env-managed'
  append_managed_line "$HOME/.bashrc" '# dev-workstation-v7: bash-env' '[ -f "$HOME/.config/dev-bootstrap/env.sh" ] && . "$HOME/.config/dev-bootstrap/env.sh"'
}

setup_zsh() {
  command -v git >/dev/null 2>&1 || { warn 'Zsh precisa de Git para Oh My Zsh/plugins'; return 0; }
  clone_managed https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  local root="$HOME/.oh-my-zsh/custom"
  clone_managed https://github.com/spaceship-prompt/spaceship-prompt.git "$root/themes/spaceship-prompt"
  if [[ -f "$root/themes/spaceship-prompt/spaceship.zsh-theme" && ! -e "$root/themes/spaceship.zsh-theme" ]]; then
    ln -s "$root/themes/spaceship-prompt/spaceship.zsh-theme" "$root/themes/spaceship.zsh-theme"
    record link "$root/themes/spaceship.zsh-theme" ''
  fi
  clone_managed https://github.com/zsh-users/zsh-autosuggestions.git "$root/plugins/zsh-autosuggestions"
  clone_managed https://github.com/zsh-users/zsh-syntax-highlighting.git "$root/plugins/zsh-syntax-highlighting"
  clone_managed https://github.com/zsh-users/zsh-completions.git "$root/plugins/zsh-completions"
  clone_managed https://github.com/zsh-users/zsh-history-substring-search.git "$root/plugins/zsh-history-substring-search"
  if [[ "$PROFILE" == full ]]; then
    clone_managed https://github.com/Aloxaf/fzf-tab.git "$root/plugins/fzf-tab"
    generate_full_dev_zsh
    write_owned "$CONFIG_DIR/full-dev.zsh" "$TMP_DIR/full-dev.zsh" '# dev-bootstrap-linux: zsh-full-managed'
  fi
  generate_dev_spaceshiprc_zsh
  write_owned "$HOME/.spaceshiprc.zsh" "$TMP_DIR/dev-spaceshiprc.zsh" '# dev-bootstrap-linux: spaceship-managed'
  generate_dev_terminal_zsh
  write_owned "$CONFIG_DIR/terminal.zsh" "$TMP_DIR/dev-terminal.zsh" '# dev-bootstrap-linux: terminal-extras-managed'
  generate_dev_zshrc
  write_owned "$CONFIG_DIR/zshrc.generated" "$TMP_DIR/dev-zshrc" '# dev-bootstrap-linux: terminal-managed'
  if [[ ! -f "$HOME/.zshrc" ]] || grep -Fq '# dev-bootstrap-linux: terminal-managed' "$HOME/.zshrc"; then
    write_owned "$HOME/.zshrc" "$TMP_DIR/dev-zshrc" '# dev-bootstrap-linux: terminal-managed'
  else
    # Preserva Zshrc existente: a única mudança é uma linha incluída com backup.
    append_managed_line "$HOME/.zshrc" '# dev-workstation-v7: zsh-entry' \
      '[ -f "$HOME/.config/dev-bootstrap/zshrc.generated" ] && source "$HOME/.config/dev-bootstrap/zshrc.generated"'
  fi
  if ((SET_DEFAULT_SHELL)) && command -v zsh >/dev/null 2>&1; then
    local zsh_path="$(command -v zsh)" current_shell="${SHELL:-}"
    if [[ "$current_shell" == "$zsh_path" ]]; then ok 'Zsh já é o shell de login'
    else
      warn "Trocará o shell de login: $current_shell -> $zsh_path. Não será revertido automaticamente."
      if confirm_risk 'Change your login shell to Zsh?'; then
        if [[ -r /etc/shells ]] && grep -Fxq "$zsh_path" /etc/shells; then chsh -s "$zsh_path" || warn 'chsh falhou';
        else warn "$zsh_path não consta em /etc/shells; nenhuma mudança realizada"; fi
      fi
    fi
  fi
}

setup_tmux_pro() {
  command -v tmux >/dev/null 2>&1 || { warn 'tmux ausente; instale nas dependências do terminal'; return 0; }
  command -v git >/dev/null 2>&1 || { warn 'Git ausente; tmux Pro sem plugins'; return 0; }
  clone_managed https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
  generate_tmux_help_txt
  write_owned "$CONFIG_DIR/tmux-help.txt" "$TMP_DIR/tmux-help.txt" 'TMUX PRO — QUICK REFERENCE'
  generate_tmux_tools_sh
  write_owned "$CONFIG_DIR/tmux-tools.sh" "$TMP_DIR/tmux-tools.sh" '# dev-bootstrap-linux: tmux-tools-managed'
  generate_tmux_ui_conf
  write_owned "$CONFIG_DIR/tmux-ui.conf" "$TMP_DIR/tmux-ui.conf" '# dev-bootstrap-linux: tmux-ui-managed'
  generate_tmux_full_conf
  if [[ "$PROFILE" == full ]]; then
    write_owned "$CONFIG_DIR/tmux-full.conf" "$TMP_DIR/tmux-full.conf" '# dev-bootstrap-linux: tmux-full-managed'
  fi
  generate_dev_tmux_conf
  write_owned "$CONFIG_DIR/tmux-main.conf" "$TMP_DIR/dev-tmux.conf" '# dev-bootstrap-linux: tmux-managed'
  if [[ ! -f "$HOME/.tmux.conf" ]] || grep -Fq '# dev-bootstrap-linux: tmux-managed' "$HOME/.tmux.conf"; then
    write_owned "$HOME/.tmux.conf" "$TMP_DIR/dev-tmux.conf" '# dev-bootstrap-linux: tmux-managed'
  else
    append_managed_line "$HOME/.tmux.conf" '# dev-workstation-v7: tmux-entry' \
      'source-file ~/.config/dev-bootstrap/tmux-main.conf'
  fi
  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || warn 'TPM: alguns plugins não foram instalados, dentro do tmux use Ctrl+A, I'
  fi
  ok 'tmux: Ctrl+A ? (ajuda), s (sessões), w (janelas), g (Git), D (Docker), K (K9s)'
  if command -v tmux >/dev/null 2>&1 && [[ -n "${TMUX:-}" ]]; then
    tmux source-file "$HOME/.tmux.conf" || warn 'Abra uma nova sessão tmux para aplicar os atalhos.'
  fi
}

install_neovim_linux() {
  if [[ "$MODE" == update && ! -x "$DATA_DIR/nvim/current/bin/nvim" ]]; then
    log 'Neovim direct installation not managed here; use its existing package manager for upgrades.'
    return 0
  fi
  local target="$DATA_DIR/nvim/current" narch='' asset='' data='' tag='' asseturl='' digest=''
  case "$ARCH" in x86_64|amd64) narch=x86_64;; aarch64|arm64) narch=arm64;;
    *) warn "Neovim: arquitetura Linux não suportada: $ARCH"; return 0;; esac
  if [[ -x "$target/bin/nvim" && "$MODE" != update ]]; then ok 'Neovim V7 já instalado'; return 0; fi
  if command -v nvim >/dev/null 2>&1 && ! owned dir "$target"; then
    local major minor
    major="$(nvim --version | awk 'NR==1 {split($2,a,"."); sub(/^v/,"",a[1]); print a[1]}' || true)"
    minor="$(nvim --version | awk 'NR==1 {split($2,a,"."); print a[2]}' || true)"
    if [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] && { ((major > 0)) || ((minor >= 11)); }; then
      ok "Neovim compatível já instalado: $(tool_version nvim)"; return 0
    fi
    warn "Neovim existente é anterior a 0.11: $(tool_version nvim). Instalando versão recente EM PARALELO, sem substituir o pacote."
  fi
  command -v jq >/dev/null 2>&1 || { warn 'Neovim requer jq'; return 0; }
  data="$(curl -fsSL --max-time 25 https://api.github.com/repos/neovim/neovim/releases/latest 2>/dev/null || true)"
  [[ -n "$data" ]] || { warn 'Neovim: API indisponível'; return 0; }
  tag="$(printf '%s' "$data" | jq -r '.tag_name // empty' || true)"
  asset="nvim-linux-$narch.tar.gz"
  asseturl="$(printf '%s' "$data" | jq -r --arg a "$asset" '[.assets[] | select(.name == $a) | .browser_download_url] | first // empty' || true)"
  digest="$(printf '%s' "$data" | jq -r --arg a "$asset" '[.assets[] | select(.name == $a) | .digest] | first // empty' || true)"
  [[ "$asseturl" == https://* && "$digest" =~ ^sha256:[a-f0-9]{64}$ ]] || { warn "Neovim $tag sem SHA256; ignorado"; return 0; }
  if [[ -x "$target/bin/nvim" && "$MODE" == update ]]; then
    local current="$("$target/bin/nvim" --version | awk 'NR==1 {print $2}' || true)"
    log "Neovim: instalada=$current | disponível=$tag"
    if ! semver_newer "$current" "$tag"; then ok 'Neovim não precisa de atualização'; return 0; fi
    if ! ((YES_UPDATES)) && ! answer_yes "Upgrade Neovim to $tag?"; then return 0; fi
  fi
  curl -fsSL --max-time 90 "$asseturl" -o "$TMP_DIR/$asset"
  sha256_verify "${digest#sha256:}" "$TMP_DIR/$asset" || die 'Neovim: checksum incorreto'
  local unp="$TMP_DIR/nvim-unpack" backup=''
  mkdir -p "$unp" "$(dirname "$target")"
  tar -xzf "$TMP_DIR/$asset" -C "$unp" --strip-components=1
  [[ -x "$unp/bin/nvim" ]] || die 'Neovim: binário não encontrado no pacote'
  if [[ -e "$target" ]]; then
    backup="$target.v7-backup-$(date +%Y%m%d-%H%M%S)-$$"
    mv "$target" "$backup"; warn "Versão anterior preservada em $backup"
  else record dir "$target" ''; fi
  mv "$unp" "$target"
  if [[ ! -e "$HOME/.local/bin/nvim" ]]; then
    ln -s "$target/bin/nvim" "$HOME/.local/bin/nvim"; record link "$HOME/.local/bin/nvim" ''
  fi
  ok "Neovim $tag disponível (reinicie o terminal para atualizar PATH)"
}

merge_lazyvim() {
  local target="$HOME/.config/nvim/lazyvim.json" old="$TMP_DIR/lazyvim-old.json" add="$TMP_DIR/lazyvim-additions.json"
  command -v jq >/dev/null 2>&1 || { warn 'jq não instalado; extras LazyVim não configurados'; return 0; }
  if [[ -e "$target" ]]; then
    if [[ -L "$target" ]] || ! jq -e 'type=="object" and (.extras==null or (.extras|type=="array"))' "$target" >/dev/null 2>&1; then
      warn "LazyVim JSON inválido ou symlink: $target; NÃO será alterado"; return 0
    fi
    cp "$target" "$old"
  else printf '{"version":8,"news":{},"extras":[]}\n' > "$old"; fi
  cat > "$add" <<'BASE_EXTRAS'
[
"lazyvim.plugins.extras.lang.java",
"lazyvim.plugins.extras.lang.go",
"lazyvim.plugins.extras.lang.typescript",
"lazyvim.plugins.extras.lang.json",
"lazyvim.plugins.extras.lang.yaml",
"lazyvim.plugins.extras.lang.docker",
"lazyvim.plugins.extras.lang.helm",
"lazyvim.plugins.extras.lang.markdown"
]
BASE_EXTRAS
  if [[ "$ONLY" == markdown ]]; then
    printf '["lazyvim.plugins.extras.lang.markdown"]\n' > "$add"
  fi
  if [[ "$PROFILE" == full && "$ONLY" != markdown ]]; then
    jq '. + ["lazyvim.plugins.extras.dap.core", "lazyvim.plugins.extras.test.core", "lazyvim.plugins.extras.util.rest", "lazyvim.plugins.extras.lang.sql", "lazyvim.plugins.extras.lang.terraform", "lazyvim.plugins.extras.lang.ansible", "lazyvim.plugins.extras.util.dot"]' "$add" > "$TMP_DIR/lazyvim-full.json"
    add="$TMP_DIR/lazyvim-full.json"
  fi
  jq --slurpfile added "$add" '.extras=((.extras//[])+$added[0]|unique)' "$old" > "$TMP_DIR/lazyvim-merged.json"
  write_owned "$target" "$TMP_DIR/lazyvim-merged.json" '"extras"'
}

setup_nvim() {
  if [[ "$PLATFORM" == macos ]]; then package neovim nvim
  else install_neovim_linux; fi
  if [[ ! -e "$HOME/.config/nvim" ]]; then
    clone_managed https://github.com/LazyVim/starter.git "$HOME/.config/nvim"
    # Mantém .git de propósito; nunca apaga conteúdo do usuário.
  fi
  if [[ -f "$HOME/.config/nvim/lua/config/lazy.lua" ]] && \
    grep -Fq 'LazyVim/LazyVim' "$HOME/.config/nvim/lua/config/lazy.lua"; then
    mkdir -p "$HOME/.config/nvim/lua/plugins"
    generate_dev_bootstrap_lua
    write_owned "$HOME/.config/nvim/lua/plugins/dev-bootstrap.lua" "$TMP_DIR/dev-bootstrap.lua" '-- dev-bootstrap-linux: lazyvim-managed'
    merge_lazyvim
    generate_dev_markdown_lua
    write_owned "$HOME/.config/nvim/lua/plugins/dev-markdown.lua" "$TMP_DIR/dev-markdown.lua" '-- dev-bootstrap-linux: markdown-managed'
  else
    warn 'Config Neovim atual não é LazyVim; preservada. Para usar os extras, configure LazyVim manualmente.'
  fi
  if ! command -v tree-sitter >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
      log 'tree-sitter-cli ausente. Instalando via npm do Node selecionado.'
      if npm install --global tree-sitter-cli; then
        record npm_global tree-sitter-cli "$(command -v npm)"
      else warn 'Falha ao instalar tree-sitter-cli via npm; LazyVim pode exigir compilação manual.'; fi
    else warn 'tree-sitter CLI ausente e npm não disponível'; fi
  fi
  warn 'Dentro de nvim execute :Lazy sync, :LazyHealth e :Mason. Plugins não são atualizados silenciosamente.'
}

setup_markdown_only() {
  if [[ ! -f "$HOME/.config/nvim/lua/config/lazy.lua" ]] || \
    ! grep -Fq 'LazyVim/LazyVim' "$HOME/.config/nvim/lua/config/lazy.lua"; then
    warn 'Markdown-only exige LazyVim existente; nada alterado'; return 0
  fi
  mkdir -p "$HOME/.config/nvim/lua/plugins"
  merge_lazyvim
  generate_dev_markdown_lua
  write_owned "$HOME/.config/nvim/lua/plugins/dev-markdown.lua" "$TMP_DIR/dev-markdown.lua" '-- dev-bootstrap-linux: markdown-managed'
}

# Dev Workstation V8 — Guia de instalação

**Menus, perguntas de confirmação, opções de escolha e ajuda do tmux em inglês.** Este guia explica os comandos em português.

## 1. Requisitos

- macOS recente com Apple Silicon ou Intel, Homebrew para os pacotes (pode ser instalado mediante autorização), ou Linux com APT, DNF, pacman ou zypper.
- Bash 3.2 ou superior, `curl` e `git` para downloads e clones conforme a etapa. O script usa privilégios administrativos apenas para ações específicas do sistema.
- Execute o script como seu usuário habitual, sem `sudo ./install.sh`.
- Rede para instalações. `--check` e `--plan` não instalam pacotes.

A compatibilidade varia por distribuição, arquitetura e disponibilidade dos repositórios. Alguns fallbacks de releases oficiais só existem para Linux x86-64/ARM64.

## 2. Primeira execução

```bash
chmod +x install.sh

# Diagnóstico com verificações funcionais de ferramentas importantes
./install.sh --check --full-dev

# Exibe o que está instalado, o que falta e as alterações previstas nos dotfiles
./install.sh --plan --full-dev --diff

# Menu interativo em inglês; utiliza Gum se ele já estiver disponível
./install.sh --menu

# Instalação interativa — perguntas por etapa
./install.sh --install --full-dev
```

A configuração `config/workstation.toml` já usa o perfil `full` por padrão. Passe `--only=java,node,go` ou edite `profile = "base"` para restringir o escopo. `--only=tmux` e `--markdown-only` funcionam como atalhos específicos.

Antes de executar, a V8 oferece atualizar os índices do gerenciador de pacotes; no Arch ela não executa `pacman -Sy`, pois isso produziria sincronização parcial arriscada.

O programa apresenta um quadro com `COMPONENT`, `TOOL`, `ACTION`, `CURRENT` e `AVAILABLE`. Os candidatos APT e outros repositórios podem estar desatualizados; as versões de binários diretos são consultadas durante a etapa autorizada, não garantidas na prévia.

## 3. Atualizar de maneira controlada

```bash
./install.sh --update --full-dev
```

O modo apresenta etapas para confirmação e solicita aprovação específica para versões comprovadamente novas. **`--yes` não autoriza atualizações**, apenas etapas de instalação. Para um ambiente supervisionado:

```bash
./install.sh --update --full-dev --yes --yes-updates
```

Atenção: dependências e atualizações de plugins podem exigir intervenção manual; no Arch não são feitas atualizações parciais. Os plugins do LazyVim continuam com `:Lazy sync` / `:LazyHealth` quando você decidir executá-los.

## 4. Perfis e seleção de módulos

```bash
./install.sh --install --only=java
./install.sh --install --only=node,go
./install.sh --install --only=docker,kubernetes
./install.sh --install --only=tmux
./install.sh --install --markdown-only
./install.sh --install --no-terminal
./install.sh --install --java21
```

Os módulos disponíveis são `basics`, `java`, `sdkman`, `node`, `go`, `docker`, `kubernetes`, `terminal`, `zsh`, `tmux`, `neovim`, `font` e `infra` (este último exige `--full-dev`).

No macOS, Docker Desktop é instalado como cask Homebrew, mas é necessário abrir o aplicativo e concluir sua configuração. No Linux, a inclusão no grupo `docker` pede autorização extra porque esse grupo possui privilégios muito altos.

## 5. Preview e arquivos do terminal

```bash
./install.sh --plan --only=tmux,zsh,neovim --diff
```

O instalador preserva arquivos pessoais, detecta arquivos previamente gerenciados por marcadores V7 e cria backups antes de alterá-los. Para arquivos conflitantes, a opção `--replace-config` permite substituição, mas **sempre revise o diff primeiro**.

O tmux utiliza `Ctrl+A`: `?` ajuda, `s` sessões, `w` janelas, `h/j/k/l` painéis, `|`/`-` divisões, `z` zoom, `g` LazyGit, `D` Lazydocker e `K` K9s. Os pop-ups precisam de tmux recente e dos programas associados. O Neovim usa LazyVim com renderização Markdown e extras Full Dev. Depois de instalar, abra `nvim` e execute `:Lazy sync` e `:LazyHealth`.

## 6. Reverter e desinstalar

```bash
# Examine primeiro, sem apagar nada
./install.sh --uninstall --all --dry-run

# Só remove recursos comprovadamente instalados e registrados pela V8
./install.sh --uninstall --all

# Inspecione uma remoção mais abrangente de diretórios gerenciados
./install.sh --uninstall --all --purge-user-data

# Restaura somente arquivos gerenciados e links seguros da última transação
./install.sh --rollback
```

A remoção requer digitar `REMOVE` em inglês; ações potencialmente destrutivas exigem confirmações adicionais. O manifesto fica em `~/.local/state/dev-workstation/ledger-v8.tsv` (ou no caminho XDG equivalente). Nunca use `rm -rf` indiscriminadamente em `~/.nvm`, `~/.sdkman`, `~/.config/nvim` ou no Docker, pois podem conter dados criados depois da instalação.

O rollback **não** reverte versões do Java, Go, pacotes APT/Homebrew, containers, bancos, arquivos Kubernetes ou clusters. Se você alterar uma configuração após a instalação, a V8 se recusa a substituí-la automaticamente quando o hash diverge.

**Limite de migração:** a V8 não considera automaticamente os recursos da V7 como de sua propriedade. Ao executar a V8, novos arquivos gerenciados passam a integrar o manifesto V8, mas as ferramentas instaladas pela V7 continuam preservadas. Desinstalação da V7 deve usar o procedimento específico daquela versão, revisando as alterações primeiro.

## 7. Exportar perfil e levar para outro computador

```bash
./install.sh --export-profile=meu-perfil.toml
# Copie apenas o perfil e a lista de versões para outra máquina.
./install.sh --config=meu-perfil.toml --plan
./install.sh --config=meu-perfil.toml --install
```

O perfil registra preferências. O arquivo `.versions.txt` é uma fotografia informativa das versões e não força instalações exatas. Não são copiados SSH, kubeconfig, credenciais, tokens, repositórios ou históricos.

## 8. Testes e compatibilidade

```bash
bash tests/test_smoke.sh
bash -n install.sh
```

Os testes cobrem diagnósticos e simulações, preservação de alterações pessoais, rollback seguro, separação de confirmações e detecção simulada do macOS. A instalação completa não foi executada em um macOS real e em todas as distribuições. Recomenda-se testar em VM ou máquina não crítica antes de uso profissional. Veja `docs/SECURITY.md`.

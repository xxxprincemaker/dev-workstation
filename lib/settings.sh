# Deliberately small TOML subset for settings; unrecognized keys are ignored.
# No eval, shell execution, variable expansion or remote fetching.
load_settings() {
  local file="$1" section='' raw key value
  [[ -f "$file" ]] || { warn "Configuration file not found: $file (using defaults)"; return 0; }
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    case "$raw" in ''|\#*) continue;; esac
    if [[ "$raw" =~ ^\[([a-zA-Z0-9_-]+)\] ]]; then section="${BASH_REMATCH[1]}"; continue; fi
    [[ "$raw" == *=* ]] || continue
    key="${raw%%=*}"; value="${raw#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    value="$(printf '%s' "$value" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//;s/^"(.*)"$/\1/')"
    case "$section.$key:$value" in
      workstation.profile:full) PROFILE=full;;
      workstation.profile:base) PROFILE=base;;
      features.java21:true) JAVA21=1;;
      features.nerd_font:false) NO_FONT=1;;
      features.terminal:false) NO_TERMINAL=1;;
      features.default_shell:true) SET_DEFAULT_SHELL=1;;
    esac
  done < "$file"
}

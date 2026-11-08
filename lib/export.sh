# Export portable desired settings and an informational tool version snapshot.
export_profile() {
  local destination="$1" version_file temp b
  [[ -n "$destination" ]] || die '--export-profile requires a file path.'
  [[ "$destination" == /* ]] || destination="$PWD/$destination"
  [[ ! -L "$destination" ]] || die 'Refusing to overwrite symlink profile.'
  mkdir -p "$(dirname "$destination")"
  temp="$(mktemp "$(dirname "$destination")/.profile.XXXXXXXX")"
  cat > "$temp" <<EOF_PROFILE
# Dev Workstation V8 — portable desired setup (no credentials)
[workstation]
profile = "$PROFILE"

[features]
java21 = $( [[ "$JAVA21" -eq 1 ]] && echo true || echo false )
nerd_font = $( [[ "$NO_FONT" -eq 0 ]] && echo true || echo false )
terminal = $( [[ "$NO_TERMINAL" -eq 0 ]] && echo true || echo false )
default_shell = false
EOF_PROFILE
  chmod 0644 "$temp"; mv "$temp" "$destination"
  version_file="${destination%.toml}.versions.txt"
  {
    printf '# Informational snapshot only. Does not pin future installs.\n'
    printf '# System: %s (%s)\n' "$DISTRO_NAME" "$ARCH"
    for b in java node npm pnpm yarn go mvn gradle docker kubectl helm terraform nvim tmux zsh; do
      if command_exists "$b"; then printf '%-12s %s\n' "$b" "$(tool_version "$b")"; fi
    done
  } > "$version_file"
  chmod 0644 "$version_file"
  ok "Portable settings: $destination"
  ok "Version snapshot: $version_file"
  warn 'No kubeconfig, SSH keys, tokens, shell history, environment secrets or Docker credentials were exported.'
}

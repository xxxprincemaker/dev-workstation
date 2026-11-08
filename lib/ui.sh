# Menus and confirmations deliberately in English; gum is optional.
ask() {
  local question="$1" response=''
  [[ "$DRY_RUN" -eq 0 && "$MODE" != check ]] || return 1
  [[ -t 0 ]] || return 1
  if command_exists gum && [[ -t 1 ]]; then
    gum confirm --default=false "$question" && return 0 || return 1
  fi
  printf '\n[ASK] %s [y/N] ' "$question" > /dev/tty
  IFS= read -r response < /dev/tty || return 1
  case "$response" in y|Y|yes|YES|Yes) return 0;; *) return 1;; esac
}
approve_step() {
  local question="$1"
  if ((YES)); then return 0; fi
  ask "$question"
}
approve_update() {
  local question="$1"
  if ((YES_UPDATES)); then return 0; fi
  ask "$question"
}
confirm_risk() {
  # Elevated/side-effectful actions never inherit --yes or --yes-updates.
  ask "$1"
}
answer_yes() {
  # Compatibility with module prompts. --yes must NEVER approve updates.
  if [[ "$MODE" == update ]]; then approve_update "$1"
  elif [[ "$MODE" == install ]]; then approve_step "$1"
  else ask "$1"; fi
}
main_menu() {
  local choice=''
  if command_exists gum && [[ -t 0 && -t 1 ]]; then
    choice="$(gum choose --header 'Dev Workstation V8 — Choose an action' \
      'Check environment' 'Preview changes' 'Install missing tools' \
      'Review updates' 'Uninstall managed items' 'Rollback last operation' 'Exit' || true)"
  else
    cat <<'MENU'

DEV WORKSTATION V8
  1) Check environment
  2) Preview changes
  3) Install missing tools
  4) Review updates
  5) Uninstall managed items
  6) Rollback last operation
  7) Exit
MENU
    if [[ -t 0 ]]; then
      printf 'Select [1-7]: ' > /dev/tty
      IFS= read -r choice < /dev/tty || choice='7'
    else choice='1'; fi
  fi
  case "$choice" in
    1|'Check environment') MODE=check ;;
    2|'Preview changes') MODE=install; DRY_RUN=1 ;;
    3|'Install missing tools') MODE=install ;;
    4|'Review updates') MODE=update ;;
    5|'Uninstall managed items') MODE=uninstall; REMOVE_ALL=1 ;;
    6|'Rollback last operation') MODE=rollback ;;
    *) MODE=exit ;;
  esac
}

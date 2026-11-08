# shellcheck shell=bash
# Common runtime — Bash 3.2 compatible.
APP=dev-workstation
SCRIPT_VERSION=8.0.0
MODE=menu
PROFILE=base
DRY_RUN=0
YES=0
YES_UPDATES=0
REPLACE_CONFIG=0
SHOW_DIFF=0
SET_DEFAULT_SHELL=0
JAVA21=0
NO_FONT=0
NO_TERMINAL=0
ONLY=''
REMOVE_ALL=0
PURGE_USER_DATA=0
CONFIRM_REMOVE=''
ISSUES=0
STEP_COUNT=0
ARCH=''
PLATFORM=''
PKG=''
BREW=''
DISTRO=''
DISTRO_NAME=''
VERSION_CODENAME=''
TMP_DIR=''
V8_TX=''
LOCK_HELD=0
STATE_DIR="${DEV_WORKSTATION_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-workstation}"
DATA_DIR="${DEV_WORKSTATION_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/dev-workstation}"
CONFIG_DIR="$HOME/.config/dev-bootstrap"
MANIFEST="$STATE_DIR/ledger-v8.tsv"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SELECTED_STAGES=''
FAILED_STAGES=0
SUCCESS_STAGES=0
PLAN_FILE=''
export NVM_DIR SDKMAN_DIR
log() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARNING] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; }
die() { fail "$*"; exit 1; }
cleanup() {
  if [[ "$LOCK_HELD" -eq 1 && -d "$STATE_DIR/.lock" ]]; then
    rm -rf "$STATE_DIR/.lock"
  fi
  [[ -z "$TMP_DIR" || ! -d "$TMP_DIR" ]] || rm -rf "$TMP_DIR"
}
trap cleanup EXIT
on_error() { local code="$1" line="$2"; fail "Operation failed at line $line (exit $code); prior steps remain recorded."; }
trap 'on_error "$?" "$LINENO"' ERR
command_exists() { command -v "$1" >/dev/null 2>&1; }
sha_file() {
  [[ -f "$1" ]] || { printf '-'; return 0; }
  if command_exists sha256sum; then sha256sum "$1" | awk '{print $1}'
  elif command_exists shasum; then shasum -a 256 "$1" | awk '{print $1}'
  else die 'SHA-256 tool missing (sha256sum/shasum).'; fi
}
safe_field() { case "$1" in *$'\n'*|*$'\t'*) return 1;; *) return 0;; esac; }
run_sdk() (
  trap - ERR
  set +Eeuo pipefail
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || return 127
  # shellcheck disable=SC1090
  . "$SDKMAN_DIR/bin/sdkman-init.sh" || return $?
  sdk "$@"
)
load_nvm() {
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 0
  set +u
  # shellcheck disable=SC1090
  . "$NVM_DIR/nvm.sh"
  set -u
}
tool_version() {
  local b="$1" output=''
  case "$b" in
    java|javac) output="$("$b" -version 2>&1 || true)" ;;
    go) output="$(go version 2>&1 || true)" ;;
    docker) output="$(docker --version 2>&1 || true)" ;;
    kubectl) output="$(kubectl version --client --output=yaml 2>&1 || true)" ;;
    sdk) output="$(run_sdk version 2>&1 || true)" ;;
    nvm) output="$(nvm --version 2>&1 || true)" ;;
    *) output="$("$b" --version 2>&1 || true)" ;;
  esac
  output="${output%%$'\n'*}"
  printf '%.72s' "${output:-unknown}"
}
version_newer() {
  # Refuse comparison of unparseable versions or prerelease suffixes.
  local older="${1#v}" newer="${2#v}" 
  older="${older#go}"; newer="${newer#go}"
  [[ "$older" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ && "$newer" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || return 1
  awk -v a="$older" -v b="$newer" 'BEGIN {split(a,x,".");split(b,y,".");for(i=1;i<=3;i++){if((y[i]+0)>(x[i]+0))exit 0;if((y[i]+0)<(x[i]+0))exit 1;}exit 1}'
}
semver_newer() { version_newer "$1" "$2"; }

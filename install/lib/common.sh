#!/usr/bin/env bash
# ==============================================================================
# common.sh — Shared functions for the HTB install scripts (OpenClaw)
# Sourced by install-kali.sh and install-ubuntu.sh
# ==============================================================================

# --- Pinned versions (sourced from versions.env if present) -----------------
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_COMMON_DIR/../versions.env" ]]; then
  # shellcheck source=/dev/null
  source "$_COMMON_DIR/../versions.env"
fi
# Defaults if versions.env is absent (scripts remain self-contained)
RUSTSCAN_VERSION="${RUSTSCAN_VERSION:-2.1.1}"
LIGOLO_VERSION="${LIGOLO_VERSION:-0.6.2}"
CHISEL_VERSION="${CHISEL_VERSION:-1.9.1}"

# --- Colors -----------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_RED='\033[0;31m'; C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'; C_BLUE='\033[0;34m'; C_CYAN='\033[0;36m'; C_BOLD='\033[1m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_BOLD=''
fi

# --- Global state ------------------------------------------------------------
INSTALL_LOG="${INSTALL_LOG:-/tmp/htb-install-$(date +%Y%m%d-%H%M%S).log}"
declare -a INSTALLED_OK=()
declare -a INSTALLED_SKIP=()
declare -a INSTALLED_FAIL=()

# --- Logging ----------------------------------------------------------------
log()   { echo -e "${C_CYAN}[*]${C_RESET} $*"    | tee -a "$INSTALL_LOG"; }
ok()    { echo -e "${C_GREEN}[+]${C_RESET} $*"   | tee -a "$INSTALL_LOG"; }
warn()  { echo -e "${C_YELLOW}[!]${C_RESET} $*"  | tee -a "$INSTALL_LOG"; }
err()   { echo -e "${C_RED}[-]${C_RESET} $*"     | tee -a "$INSTALL_LOG" >&2; }
section(){ echo -e "\n${C_BOLD}${C_BLUE}=== $* ===${C_RESET}" | tee -a "$INSTALL_LOG"; }

# --- Privilege detection ----------------------------------------------------
# SUDO is empty if we are root, otherwise "sudo"
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

require_sudo() {
  if [[ -n "$SUDO" ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      err "sudo is not installed and you are not root. Aborting."
      exit 1
    fi
    log "Elevating privileges (you may be prompted for your password)…"
    $SUDO -v || { err "Unable to obtain sudo privileges."; exit 1; }
  fi
}

# --- Helpers ----------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# idempotent apt install: only installs what is missing
apt_pkgs() {
  local pkgs=("$@") missing=()
  for p in "${pkgs[@]}"; do
    if dpkg -s "$p" >/dev/null 2>&1; then
      INSTALLED_SKIP+=("$p")
    else
      missing+=("$p")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log "apt install: ${missing[*]}"
    if DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends "${missing[@]}" >>"$INSTALL_LOG" 2>&1; then
      for p in "${missing[@]}"; do INSTALLED_OK+=("$p"); done
    else
      err "apt failed for: ${missing[*]} (see $INSTALL_LOG)"
      for p in "${missing[@]}"; do INSTALLED_FAIL+=("$p"); done
    fi
  fi
}

# idempotent pipx install
pipx_install() {
  local spec="$1" name="${2:-$1}"
  if ! have pipx; then err "pipx missing, skip $name"; INSTALLED_FAIL+=("$name(pipx)"); return 1; fi
  if pipx list 2>/dev/null | grep -qi "package $name"; then
    INSTALLED_SKIP+=("$name")
    return 0
  fi
  log "pipx install: $spec"
  if pipx install "$spec" >>"$INSTALL_LOG" 2>&1; then
    INSTALLED_OK+=("$name")
  else
    err "pipx failed: $spec"
    INSTALLED_FAIL+=("$name(pipx)")
  fi
}

# idempotent go install (requires Go in PATH)
go_install() {
  local pkg="$1" bin="$2"
  if ! have go; then err "Go missing, skip $bin"; INSTALLED_FAIL+=("$bin(go)"); return 1; fi
  if have "$bin"; then INSTALLED_SKIP+=("$bin"); return 0; fi
  log "go install: $pkg"
  if GOBIN="${GOBIN:-/usr/local/bin}" $SUDO env "PATH=$PATH" GOBIN="${GOBIN:-/usr/local/bin}" go install "$pkg" >>"$INSTALL_LOG" 2>&1; then
    INSTALLED_OK+=("$bin")
  else
    # 2nd attempt without sudo, into $HOME/go/bin
    if go install "$pkg" >>"$INSTALL_LOG" 2>&1; then
      INSTALLED_OK+=("$bin (~/go/bin)")
    else
      err "go install failed: $pkg"
      INSTALLED_FAIL+=("$bin(go)")
    fi
  fi
}

# idempotent git clone into /opt
git_clone_opt() {
  local url="$1" dest="/opt/$2"
  if [[ -d "$dest/.git" ]]; then
    INSTALLED_SKIP+=("$(basename "$dest")")
    ( cd "$dest" && $SUDO git pull --ff-only >>"$INSTALL_LOG" 2>&1 ) || true
    return 0
  fi
  log "git clone: $url -> $dest"
  if $SUDO git clone --depth 1 "$url" "$dest" >>"$INSTALL_LOG" 2>&1; then
    INSTALLED_OK+=("$(basename "$dest")")
  else
    err "git clone failed: $url"
    INSTALLED_FAIL+=("$(basename "$dest")")
  fi
}

# --- Final summary ----------------------------------------------------------
print_summary() {
  section "Installation summary"
  ok "Installed (${#INSTALLED_OK[@]}): ${INSTALLED_OK[*]:-none}"
  [[ ${#INSTALLED_SKIP[@]} -gt 0 ]] && log "Already present (${#INSTALLED_SKIP[@]}): ${INSTALLED_SKIP[*]}"
  if [[ ${#INSTALLED_FAIL[@]} -gt 0 ]]; then
    err "Failures (${#INSTALLED_FAIL[@]}): ${INSTALLED_FAIL[*]}"
    warn "See the detailed log: $INSTALL_LOG"
  fi
  echo
  ok "Full log: $INSTALL_LOG"
  warn "Reminder: these tools are intended for authorized testing only (HTB, labs, CTF, systems you own)."
}

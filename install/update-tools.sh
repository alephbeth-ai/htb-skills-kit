#!/usr/bin/env bash
# ==============================================================================
# update-tools.sh — Checks/refreshes the pinned tools and git repositories
# ------------------------------------------------------------------------------
#   --check   : compares the versions in versions.env against the latest
#               GitHub releases (read-only, changes nothing).
#   --pull    : updates (git pull) the repositories cloned in /opt (GIT_REPOS).
#   (default) : --check
#
# Requires curl. 'jq' is used if present, otherwise basic parsing.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/versions.env" ]] && source "$SCRIPT_DIR/versions.env"

if [[ -t 1 ]]; then G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'; else G=''; R=''; Y=''; B=''; N=''; fi
log(){ echo -e "$@"; }

# Fetches the latest release tag of a GitHub repo (owner/repo)
latest_gh() {
  local repo="$1" url="https://api.github.com/repos/$1/releases/latest" tag
  if command -v jq >/dev/null 2>&1; then
    tag="$(curl -fsSL "$url" 2>/dev/null | jq -r '.tag_name // empty')"
  else
    tag="$(curl -fsSL "$url" 2>/dev/null | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  fi
  echo "${tag#v}"
}

check_one() {
  local name="$1" repo="$2" current="$3" latest
  latest="$(latest_gh "$repo")"
  if [[ -z "$latest" ]]; then
    printf "  ${Y}?${N} %-12s current=%-10s latest=? (GitHub unreachable / rate-limit)\n" "$name" "$current"
    return
  fi
  if [[ "$current" == "$latest" ]]; then
    printf "  ${G}✔${N} %-12s up to date (%s)\n" "$name" "$current"
  else
    printf "  ${Y}↑${N} %-12s current=%-10s ${B}latest=%s${N}  -> edit versions.env\n" "$name" "$current" "$latest"
  fi
}

do_check() {
  log "${B}== Pinned versions vs latest GitHub releases ==${N}"
  check_one "rustscan"  "RustScan/RustScan" "${RUSTSCAN_VERSION:-?}"
  check_one "ligolo-ng" "nicocha30/ligolo-ng" "${LIGOLO_VERSION:-?}"
  check_one "chisel"    "jpillora/chisel" "${CHISEL_VERSION:-?}"
  log "\n${B}== Tracked git repositories (default branch) ==${N}"
  for entry in "${GIT_REPOS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    local name="${entry##*|}"
    if [[ -d "/opt/$name/.git" ]]; then
      printf "  ${G}✔${N} %-24s cloned in /opt/%s\n" "$name" "$name"
    else
      printf "  ${Y}?${N} %-24s not cloned (re-run install)\n" "$name"
    fi
  done
  log "\n${Y}Note:${N} after editing versions.env, re-run ./install-<distro>.sh <group> to reinstall."
}

do_pull() {
  local sudo=""; [[ "${EUID:-$(id -u)}" -ne 0 ]] && sudo="sudo"
  log "${B}== Updating git repositories in /opt ==${N}"
  for entry in "${GIT_REPOS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    local name="${entry##*|}" dir="/opt/${entry##*|}"
    if [[ -d "$dir/.git" ]]; then
      log "  git pull $name…"
      if $sudo git -C "$dir" pull --ff-only >/dev/null 2>&1; then
        printf "  ${G}✔${N} %s up to date\n" "$name"
      else
        printf "  ${R}x${N} %s : pull failed\n" "$name"
      fi
    else
      printf "  ${Y}?${N} %s not cloned (skip)\n" "$name"
    fi
  done
}

case "${1:---check}" in
  --check) do_check ;;
  --pull)  do_pull ;;
  -h|--help) echo "Usage: $0 [--check|--pull]"; exit 0 ;;
  *) echo "Unknown option: $1"; echo "Usage: $0 [--check|--pull]"; exit 1 ;;
esac

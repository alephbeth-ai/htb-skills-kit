#!/usr/bin/env bash
# ==============================================================================
# update-tools.sh — Vérifie/rafraîchit les outils épinglés et les dépôts git
# ------------------------------------------------------------------------------
#   --check   : compare les versions de versions.env aux dernières releases
#               GitHub (lecture seule, ne modifie rien).
#   --pull    : met à jour (git pull) les dépôts clonés dans /opt (GIT_REPOS).
#   (défaut)  : --check
#
# Nécessite curl. 'jq' est utilisé si présent, sinon parsing basique.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/versions.env" ]] && source "$SCRIPT_DIR/versions.env"

if [[ -t 1 ]]; then G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'; else G=''; R=''; Y=''; B=''; N=''; fi
log(){ echo -e "$@"; }

# Récupère le dernier tag de release d'un repo GitHub (owner/repo)
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
    printf "  ${Y}?${N} %-12s actuel=%-10s dernier=? (GitHub injoignable / rate-limit)\n" "$name" "$current"
    return
  fi
  if [[ "$current" == "$latest" ]]; then
    printf "  ${G}✔${N} %-12s à jour (%s)\n" "$name" "$current"
  else
    printf "  ${Y}↑${N} %-12s actuel=%-10s ${B}dernier=%s${N}  -> éditez versions.env\n" "$name" "$current" "$latest"
  fi
}

do_check() {
  log "${B}== Versions épinglées vs dernières releases GitHub ==${N}"
  check_one "rustscan"  "RustScan/RustScan" "${RUSTSCAN_VERSION:-?}"
  check_one "ligolo-ng" "nicocha30/ligolo-ng" "${LIGOLO_VERSION:-?}"
  check_one "chisel"    "jpillora/chisel" "${CHISEL_VERSION:-?}"
  log "\n${B}== Dépôts git suivis (branche par défaut) ==${N}"
  for entry in "${GIT_REPOS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    local name="${entry##*|}"
    if [[ -d "/opt/$name/.git" ]]; then
      printf "  ${G}✔${N} %-24s cloné dans /opt/%s\n" "$name" "$name"
    else
      printf "  ${Y}?${N} %-24s non cloné (relancer install)\n" "$name"
    fi
  done
  log "\n${Y}Note :${N} après édition de versions.env, relancez ./install-<distro>.sh <groupe> pour réinstaller."
}

do_pull() {
  local sudo=""; [[ "${EUID:-$(id -u)}" -ne 0 ]] && sudo="sudo"
  log "${B}== Mise à jour des dépôts git dans /opt ==${N}"
  for entry in "${GIT_REPOS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    local name="${entry##*|}" dir="/opt/${entry##*|}"
    if [[ -d "$dir/.git" ]]; then
      log "  git pull $name…"
      if $sudo git -C "$dir" pull --ff-only >/dev/null 2>&1; then
        printf "  ${G}✔${N} %s à jour\n" "$name"
      else
        printf "  ${R}x${N} %s : échec du pull\n" "$name"
      fi
    else
      printf "  ${Y}?${N} %s non cloné (skip)\n" "$name"
    fi
  done
}

case "${1:---check}" in
  --check) do_check ;;
  --pull)  do_pull ;;
  -h|--help) echo "Usage: $0 [--check|--pull]"; exit 0 ;;
  *) echo "Option inconnue: $1"; echo "Usage: $0 [--check|--pull]"; exit 1 ;;
esac

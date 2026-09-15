#!/usr/bin/env bash
# ==============================================================================
# check-tools.sh — Vérifie la présence et l'état des outils HTB (OpenClaw)
# ------------------------------------------------------------------------------
# À lancer après installation, ou avant une box, pour savoir sur quoi compter.
# Affiche un tableau OK / ABSENT par groupe, un total, et un code de sortie
# non nul si des outils manquent (utile en CI).
#
# Usage :
#   ./check-tools.sh            # tous les groupes
#   ./check-tools.sh web ad     # groupes ciblés
#   ./check-tools.sh --quiet    # seulement le résumé
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 ]]; then
  G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'; C='\033[0;36m'
else G=''; R=''; Y=''; B=''; N=''; C=''; fi

QUIET=0; ARGS=()
for a in "$@"; do
  case "$a" in
    --quiet|-q) QUIET=1 ;;
    -h|--help) echo "Usage: $0 [--quiet] [groupes...]"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

# Groupe -> "binaire:paquet-affiché ..." (binaire testé via command -v ;
# certains outils ont un chemin fixe testé à part plus bas).
declare -A TOOLSETS
TOOLSETS[core]="git curl wget python3 pipx go jq"
TOOLSETS[recon]="nmap masscan rustscan autorecon"
TOOLSETS[web]="ffuf feroxbuster gobuster nikto whatweb wpscan httpx subfinder nuclei dirsearch"
TOOLSETS[smb]="smbclient smbmap enum4linux-ng netexec ldapsearch impacket-secretsdump ldapdomaindump"
TOOLSETS[ad]="netexec kerbrute certipy evil-winrm bloodhound-python neo4j"
TOOLSETS[passwords]="hydra john hashcat hash-identifier cewl medusa"
TOOLSETS[exploit]="msfconsole searchsploit"
TOOLSETS[shells]="nc socat pwncat-cs"
TOOLSETS[pivot]="proxychains4 sshuttle chisel ligolo-proxy"

# Ordre d'affichage
ORDER=(core recon web smb ad passwords exploit shells pivot)

# Fichiers/dossiers attendus (hors PATH)
declare -A PATHS
PATHS[SecLists]="/usr/share/seclists /opt/SecLists"
PATHS[rockyou]="/usr/share/wordlists/rockyou.txt"
PATHS[linpeas]="/opt/PEASS-ng/linPEAS /usr/share/peass"
PATHS[pspy]="/opt/pspy /usr/bin/pspy64"

have() { command -v "$1" >/dev/null 2>&1; }
# shellcheck disable=SC2086  # découpage voulu : liste de chemins séparés par espaces
path_exists() { local p; for p in $1; do [[ -e "$p" ]] && return 0; done; return 1; }

# Quelques alias : binaire réel différent du nom affiché
resolve() {
  case "$1" in
    proxychains4) have proxychains4 || have proxychains ;;
    nc) have nc || have ncat || have netcat ;;
    hash-identifier) have hash-identifier || have hashid || have hash-id ;;
    *) have "$1" ;;
  esac
}

TOTAL_OK=0; TOTAL_MISS=0; MISSING=()

echo -e "${B}== Vérification des outils HTB ==${N}"
for g in "${ORDER[@]}"; do
  # filtrer si des groupes ont été demandés
  if [[ ${#ARGS[@]} -gt 0 ]]; then
    printf '%s\n' "${ARGS[@]}" | grep -qx "$g" || continue
  fi
  [[ -z "${TOOLSETS[$g]:-}" ]] && continue
  [[ $QUIET -eq 0 ]] && echo -e "\n${C}[$g]${N}"
  # shellcheck disable=SC2086  # découpage voulu : liste de binaires séparés par espaces
  for bin in ${TOOLSETS[$g]}; do
    if resolve "$bin"; then
      TOTAL_OK=$((TOTAL_OK+1))
      [[ $QUIET -eq 0 ]] && printf "  ${G}✔${N} %-22s %s\n" "$bin" "$(command -v "$bin" 2>/dev/null || echo)"
    else
      TOTAL_MISS=$((TOTAL_MISS+1)); MISSING+=("$bin")
      [[ $QUIET -eq 0 ]] && printf "  ${R}x${N} %-22s ${R}ABSENT${N}\n" "$bin"
    fi
  done
done

# Ressources non-PATH (affichées si on ne cible pas de groupe précis)
if [[ ${#ARGS[@]} -eq 0 ]]; then
  [[ $QUIET -eq 0 ]] && echo -e "\n${C}[ressources]${N}"
  for res in SecLists rockyou linpeas pspy; do
    if path_exists "${PATHS[$res]}"; then
      TOTAL_OK=$((TOTAL_OK+1))
      [[ $QUIET -eq 0 ]] && printf "  ${G}✔${N} %-22s\n" "$res"
    else
      TOTAL_MISS=$((TOTAL_MISS+1)); MISSING+=("$res")
      [[ $QUIET -eq 0 ]] && printf "  ${Y}?${N} %-22s ${Y}introuvable${N}\n" "$res"
    fi
  done
fi

echo -e "\n${B}== Résumé ==${N}"
echo -e "  Présents : ${G}${TOTAL_OK}${N}   Manquants : ${R}${TOTAL_MISS}${N}"
if [[ $TOTAL_MISS -gt 0 ]]; then
  echo -e "  ${Y}Manquants :${N} ${MISSING[*]}"
  echo -e "  Installer : ${B}./install-<kali|ubuntu>.sh <groupe>${N}"
  exit 1
fi
echo -e "  ${G}Tout est en place.${N}"

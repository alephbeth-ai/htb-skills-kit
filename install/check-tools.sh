#!/usr/bin/env bash
# ==============================================================================
# check-tools.sh — Checks the presence and status of HTB tools (OpenClaw)
# ------------------------------------------------------------------------------
# Run after installation, or before a box, to know what you can rely on.
# Prints an OK / MISSING table per group, a total, and a non-zero exit code
# if tools are missing (useful in CI).
#
# Usage:
#   ./check-tools.sh            # all groups
#   ./check-tools.sh web ad     # targeted groups
#   ./check-tools.sh --quiet    # summary only
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
    -h|--help) echo "Usage: $0 [--quiet] [groups...]"; exit 0 ;;
    *) ARGS+=("$a") ;;
  esac
done

# Group -> "binary:displayed-package ..." (binary tested via command -v;
# some tools have a fixed path tested separately below).
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

# Display order
ORDER=(core recon web smb ad passwords exploit shells pivot)

# Expected files/directories (outside PATH)
declare -A PATHS
PATHS[SecLists]="/usr/share/seclists /opt/SecLists"
PATHS[rockyou]="/usr/share/wordlists/rockyou.txt"
PATHS[linpeas]="/opt/PEASS-ng/linPEAS /usr/share/peass"
PATHS[pspy]="/opt/pspy /usr/bin/pspy64"

have() { command -v "$1" >/dev/null 2>&1; }
# shellcheck disable=SC2086  # intentional splitting: space-separated list of paths
path_exists() { local p; for p in $1; do [[ -e "$p" ]] && return 0; done; return 1; }

# A few aliases: real binary differs from the displayed name
resolve() {
  case "$1" in
    proxychains4) have proxychains4 || have proxychains ;;
    nc) have nc || have ncat || have netcat ;;
    hash-identifier) have hash-identifier || have hashid || have hash-id ;;
    *) have "$1" ;;
  esac
}

TOTAL_OK=0; TOTAL_MISS=0; MISSING=()

echo -e "${B}== HTB tools check ==${N}"
for g in "${ORDER[@]}"; do
  # filter if groups were requested
  if [[ ${#ARGS[@]} -gt 0 ]]; then
    printf '%s\n' "${ARGS[@]}" | grep -qx "$g" || continue
  fi
  [[ -z "${TOOLSETS[$g]:-}" ]] && continue
  [[ $QUIET -eq 0 ]] && echo -e "\n${C}[$g]${N}"
  # shellcheck disable=SC2086  # intentional splitting: space-separated list of binaries
  for bin in ${TOOLSETS[$g]}; do
    if resolve "$bin"; then
      TOTAL_OK=$((TOTAL_OK+1))
      [[ $QUIET -eq 0 ]] && printf "  ${G}✔${N} %-22s %s\n" "$bin" "$(command -v "$bin" 2>/dev/null || echo)"
    else
      TOTAL_MISS=$((TOTAL_MISS+1)); MISSING+=("$bin")
      [[ $QUIET -eq 0 ]] && printf "  ${R}x${N} %-22s ${R}MISSING${N}\n" "$bin"
    fi
  done
done

# Non-PATH resources (shown when no specific group is targeted)
if [[ ${#ARGS[@]} -eq 0 ]]; then
  [[ $QUIET -eq 0 ]] && echo -e "\n${C}[resources]${N}"
  for res in SecLists rockyou linpeas pspy; do
    if path_exists "${PATHS[$res]}"; then
      TOTAL_OK=$((TOTAL_OK+1))
      [[ $QUIET -eq 0 ]] && printf "  ${G}✔${N} %-22s\n" "$res"
    else
      TOTAL_MISS=$((TOTAL_MISS+1)); MISSING+=("$res")
      [[ $QUIET -eq 0 ]] && printf "  ${Y}?${N} %-22s ${Y}not found${N}\n" "$res"
    fi
  done
fi

echo -e "\n${B}== Summary ==${N}"
echo -e "  Present : ${G}${TOTAL_OK}${N}   Missing : ${R}${TOTAL_MISS}${N}"
if [[ $TOTAL_MISS -gt 0 ]]; then
  echo -e "  ${Y}Missing:${N} ${MISSING[*]}"
  echo -e "  Install : ${B}./install-<kali|ubuntu>.sh <group>${N}"
  exit 1
fi
echo -e "  ${G}Everything is in place.${N}"

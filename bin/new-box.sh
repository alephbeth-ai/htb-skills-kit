#!/usr/bin/env bash
# ==============================================================================
# new-box.sh — Prepares an HTB engagement folder (OpenClaw / htb-workflow)
# ------------------------------------------------------------------------------
# Creates the directory tree and state files expected by the htb-* skills:
#   notes.md, creds.txt, techniques.txt, scans/, loot/, exploits/, www/
# Optionally adds the hostname to /etc/hosts.
#
# Usage:
#   ./new-box.sh <name> <ip> [hostname]
#   ./new-box.sh Forest 10.10.10.161 forest.htb
#   ./new-box.sh Forest 10.10.10.161 forest.htb --hosts   # writes to /etc/hosts
#
# The folder is created in $HTB_DIR (default: ~/htb) or the current directory.
# ==============================================================================
set -uo pipefail

if [[ -t 1 ]]; then G='\033[0;32m'; C='\033[0;36m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'; else G=''; C=''; Y=''; B=''; N=''; fi
die(){ echo -e "${Y}[!] $*${N}" >&2; exit 1; }

[[ $# -lt 2 ]] && { echo "Usage: $0 <name> <ip> [hostname] [--hosts]"; exit 1; }
NAME="$1"; IP="$2"; HOSTNAME_ARG=""; DO_HOSTS=0
shift 2
for a in "$@"; do
  case "$a" in
    --hosts) DO_HOSTS=1 ;;
    *) HOSTNAME_ARG="$a" ;;
  esac
done

# Basic IP validation
[[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "Invalid IP: $IP"

BASE="${HTB_DIR:-$HOME/htb}"
SLUG="$(echo "$NAME" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DIR="$BASE/$SLUG"
DATE="$(date +%Y-%m-%d)"

[[ -e "$DIR" ]] && die "The folder already exists: $DIR"
mkdir -p "$DIR"/{scans,loot,exploits,www}
echo -e "${C}[*]${N} Folder: ${B}$DIR${N}"

# --- creds.txt (htb-workflow format) ---------------------------------------
cat > "$DIR/creds.txt" <<EOF
# creds.txt — harvested credentials (replay every validated cred EVERYWHERE)
# host | service | domain | user | secret | type | source | validated(y/n)
# type ∈ password | hash | ntlm | key | ticket
EOF

# --- techniques.txt (input for the ATT&CK Navigator report) ----------------
cat > "$DIR/techniques.txt" <<EOF
# techniques.txt — MITRE ATT&CK techniques used (one ID[:comment]/line)
# Generate the layer: python3 gen-navigator-layer.py -n "$NAME" -f techniques.txt -o $SLUG.json
EOF

# --- notes.md (htb-workflow skeleton) --------------------------------------
cat > "$DIR/notes.md" <<EOF
# $NAME — $IP
Started on $DATE  |  hostname: ${HOSTNAME_ARG:-?}

## Current ATT&CK state: Reconnaissance (TA0043)

## Ports & services (htb-recon)
<!-- paste the summarized nmap output here -->

## Web surface (htb-web-enum)

## SMB / AD (htb-smb-enum / htb-active-directory)

## Foothold (how obtained — T####)

## PrivEsc (vector — T####)

## Internal hosts (htb-pivoting)

## Flags
- user.txt :
- root.txt :
EOF

# --- reminder of the first commands ----------------------------------------
cat > "$DIR/scans/_cmds.txt" <<EOF
# First commands (adapt them). LHOST = VPN interface tun0 !
IP=$IP
rustscan -a \$IP --ulimit 5000 -- -sV | tee scans/rustscan.txt
nmap -p- --min-rate 5000 -T4 \$IP -oN scans/nmap-allports.txt
# then nmap -sC -sV -p <ports> \$IP -oN scans/nmap-deep.txt
EOF

ok_hosts=""
if [[ $DO_HOSTS -eq 1 && -n "$HOSTNAME_ARG" ]]; then
  LINE="$IP $HOSTNAME_ARG"
  if grep -qE "^\s*$IP\s+$HOSTNAME_ARG\b" /etc/hosts 2>/dev/null; then
    ok_hosts="(already present)"
  else
    if echo "$LINE" | sudo tee -a /etc/hosts >/dev/null 2>&1; then
      ok_hosts="added"
    else
      ok_hosts="${Y}failed (permissions?)${N}"
    fi
  fi
fi

echo -e "${G}[+]${N} Files created: notes.md, creds.txt, techniques.txt, scans/_cmds.txt"
[[ -n "$ok_hosts" ]] && echo -e "${G}[+]${N} /etc/hosts : $IP $HOSTNAME_ARG $ok_hosts"
echo -e "${C}[*]${N} cd \"$DIR\" && cat scans/_cmds.txt"
echo -e "${Y}[!]${N} Authorized target only (assigned HTB / lab / CTF)."

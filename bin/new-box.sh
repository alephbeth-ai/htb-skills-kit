#!/usr/bin/env bash
# ==============================================================================
# new-box.sh — Prépare un dossier d'engagement HTB (OpenClaw / htb-workflow)
# ------------------------------------------------------------------------------
# Crée l'arborescence et les fichiers d'état attendus par les skills htb-* :
#   notes.md, creds.txt, techniques.txt, scans/, loot/, exploits/, www/
# Optionnellement ajoute le hostname dans /etc/hosts.
#
# Usage :
#   ./new-box.sh <nom> <ip> [hostname]
#   ./new-box.sh Forest 10.10.10.161 forest.htb
#   ./new-box.sh Forest 10.10.10.161 forest.htb --hosts   # écrit dans /etc/hosts
#
# Le dossier est créé dans $HTB_DIR (défaut: ~/htb) ou le répertoire courant.
# ==============================================================================
set -uo pipefail

if [[ -t 1 ]]; then G='\033[0;32m'; C='\033[0;36m'; Y='\033[0;33m'; B='\033[1m'; N='\033[0m'; else G=''; C=''; Y=''; B=''; N=''; fi
die(){ echo -e "${Y}[!] $*${N}" >&2; exit 1; }

[[ $# -lt 2 ]] && { echo "Usage: $0 <nom> <ip> [hostname] [--hosts]"; exit 1; }
NAME="$1"; IP="$2"; HOSTNAME_ARG=""; DO_HOSTS=0
shift 2
for a in "$@"; do
  case "$a" in
    --hosts) DO_HOSTS=1 ;;
    *) HOSTNAME_ARG="$a" ;;
  esac
done

# Validation IP basique
[[ "$IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || die "IP invalide : $IP"

BASE="${HTB_DIR:-$HOME/htb}"
SLUG="$(echo "$NAME" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
DIR="$BASE/$SLUG"
DATE="$(date +%Y-%m-%d)"

[[ -e "$DIR" ]] && die "Le dossier existe déjà : $DIR"
mkdir -p "$DIR"/{scans,loot,exploits,www}
echo -e "${C}[*]${N} Dossier : ${B}$DIR${N}"

# --- creds.txt (format htb-workflow) ---------------------------------------
cat > "$DIR/creds.txt" <<EOF
# creds.txt — identifiants récoltés (rejouer chaque cred validé PARTOUT)
# host | service | domaine | user | secret | type | source | validé(o/n)
# type ∈ password | hash | ntlm | key | ticket
EOF

# --- techniques.txt (entrée du rapport ATT&CK Navigator) -------------------
cat > "$DIR/techniques.txt" <<EOF
# techniques.txt — techniques MITRE ATT&CK employées (un ID[:commentaire]/ligne)
# Génère le layer : python3 gen-navigator-layer.py -n "$NAME" -f techniques.txt -o $SLUG.json
EOF

# --- notes.md (squelette htb-workflow) -------------------------------------
cat > "$DIR/notes.md" <<EOF
# $NAME — $IP
Démarré le $DATE  |  hostname : ${HOSTNAME_ARG:-?}

## État ATT&CK courant : Reconnaissance (TA0043)

## Ports & services (htb-recon)
<!-- coller ici la sortie nmap synthétique -->

## Surface web (htb-web-enum)

## SMB / AD (htb-smb-enum / htb-active-directory)

## Foothold (comment obtenu — T####)

## PrivEsc (vecteur — T####)

## Hosts internes (htb-pivoting)

## Flags
- user.txt :
- root.txt :
EOF

# --- rappel des premières commandes ----------------------------------------
cat > "$DIR/scans/_cmds.txt" <<EOF
# Premières commandes (adapter). LHOST = interface VPN tun0 !
IP=$IP
rustscan -a \$IP --ulimit 5000 -- -sV | tee scans/rustscan.txt
nmap -p- --min-rate 5000 -T4 \$IP -oN scans/nmap-allports.txt
# puis nmap -sC -sV -p <ports> \$IP -oN scans/nmap-deep.txt
EOF

ok_hosts=""
if [[ $DO_HOSTS -eq 1 && -n "$HOSTNAME_ARG" ]]; then
  LINE="$IP $HOSTNAME_ARG"
  if grep -qE "^\s*$IP\s+$HOSTNAME_ARG\b" /etc/hosts 2>/dev/null; then
    ok_hosts="(déjà présent)"
  else
    if echo "$LINE" | sudo tee -a /etc/hosts >/dev/null 2>&1; then
      ok_hosts="ajouté"
    else
      ok_hosts="${Y}échec (droits ?)${N}"
    fi
  fi
fi

echo -e "${G}[+]${N} Fichiers créés : notes.md, creds.txt, techniques.txt, scans/_cmds.txt"
[[ -n "$ok_hosts" ]] && echo -e "${G}[+]${N} /etc/hosts : $IP $HOSTNAME_ARG $ok_hosts"
echo -e "${C}[*]${N} cd \"$DIR\" && cat scans/_cmds.txt"
echo -e "${Y}[!]${N} Cible autorisée uniquement (HTB assignée / lab / CTF)."

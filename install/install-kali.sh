#!/usr/bin/env bash
# ==============================================================================
# install-kali.sh — Outils HTB principaux pour Kali Linux (OpenClaw)
# ------------------------------------------------------------------------------
# Kali embarque déjà la plupart des outils. Ce script garantit qu'ils sont
# présents, ajoute les métapaquets utiles et installe les outils modernes
# (netexec, ligolo-ng, feroxbuster, subfinder, etc.) absents par défaut.
#
# Usage :
#   chmod +x install-kali.sh && ./install-kali.sh            # tout
#   ./install-kali.sh core web ad                            # groupes ciblés
#   ./install-kali.sh --list                                 # lister les groupes
#
# ⚠️  Usage légal uniquement : Hack The Box, labs, CTF, systèmes autorisés.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

GROUPS_ALL=(core recon web smb ad passwords exploit shells privesc pivot wordlists)

usage() {
  cat <<EOF
${C_BOLD}install-kali.sh${C_RESET} — installe les outils HTB sur Kali Linux

Usage : $0 [groupes...]   (aucun argument = tous les groupes)

Groupes disponibles :
  core       git, python, pipx, go, build-essential, jq, net-tools…
  recon      nmap, masscan, rustscan, autorecon
  web        ffuf, feroxbuster, gobuster, nikto, whatweb, wpscan, subfinder, httpx
  smb        enum4linux-ng, smbmap, netexec, ldapdomaindump, impacket
  ad         bloodhound, neo4j, kerbrute, certipy, evil-winrm, netexec
  passwords  hydra, john, hashcat, seclists-based cewl, crackmapexec
  exploit    metasploit, exploitdb (searchsploit)
  shells     netcat, socat, pwncat-cs, evil-winrm
  privesc    peass-ng (linpeas/winpeas), pspy, linux-exploit-suggester
  pivot      chisel, ligolo-ng, proxychains, sshuttle
  wordlists  seclists, rockyou

Options :
  --list     affiche les groupes puis quitte
  -h,--help  cette aide
EOF
}

# --- Parsing arguments ------------------------------------------------------
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list) printf '%s\n' "${GROUPS_ALL[@]}"; exit 0 ;;
esac
if [[ $# -eq 0 ]]; then
  GROUPS=("${GROUPS_ALL[@]}")
else
  GROUPS=("$@")
fi

# --- Vérif OS ---------------------------------------------------------------
if ! grep -qi kali /etc/os-release 2>/dev/null; then
  warn "Système non identifié comme Kali. Utilisez plutôt install-ubuntu.sh sur Debian/Ubuntu."
  read -rp "Continuer quand même ? [y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || exit 1
fi

require_sudo
section "Mise à jour des dépôts"
$SUDO apt-get update -y >>"$INSTALL_LOG" 2>&1 || warn "apt update a renvoyé une erreur (voir log)"

in_group() { local g; for g in "${GROUPS[@]}"; do [[ "$g" == "$1" ]] && return 0; done; return 1; }

# ============================================================================
# GROUPES
# ============================================================================

if in_group core; then
  section "core — bases système et langages"
  apt_pkgs git curl wget build-essential python3 python3-pip python3-venv pipx \
           golang-go jq net-tools dnsutils vim tmux unzip ripgrep
  pipx ensurepath >>"$INSTALL_LOG" 2>&1 || true
fi

if in_group recon; then
  section "recon — découverte & scan"
  apt_pkgs nmap masscan autorecon
  # rustscan : paquet .deb officiel (pas dans les dépôts par défaut)
  if ! have rustscan; then
    log "Installation de rustscan (.deb GitHub)…"
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/rustscan.deb" \
        "https://github.com/RustScan/RustScan/releases/download/${RUSTSCAN_VERSION}/rustscan_${RUSTSCAN_VERSION}_amd64.deb" >>"$INSTALL_LOG" 2>&1 \
        && $SUDO dpkg -i "$tmp/rustscan.deb" >>"$INSTALL_LOG" 2>&1; then
      INSTALLED_OK+=("rustscan")
    else
      warn "rustscan : échec via .deb, essai cargo/go ignoré."; INSTALLED_FAIL+=("rustscan")
    fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("rustscan"); fi
fi

if in_group web; then
  section "web — énumération & fuzzing"
  apt_pkgs ffuf feroxbuster gobuster nikto whatweb wpscan dirb dirsearch wfuzz
  go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest" httpx
  go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" subfinder
  go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" nuclei
fi

if in_group smb; then
  section "smb — services réseau Windows/Unix"
  apt_pkgs smbclient smbmap enum4linux enum4linux-ng ldap-utils rpcbind \
           python3-impacket ldapdomaindump onesixtyone snmp
  # netexec (successeur de crackmapexec)
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
fi

if in_group ad; then
  section "ad — Active Directory"
  apt_pkgs bloodhound neo4j kerbrute evil-winrm
  pipx_install certipy-ad certipy-ad
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
  warn "BloodHound : démarrez neo4j avec 'sudo neo4j console' (identifiants par défaut neo4j/neo4j)."
fi

if in_group passwords; then
  section "passwords — brute force & cracking"
  apt_pkgs hydra john hashcat hash-identifier cewl crackmapexec medusa
fi

if in_group exploit; then
  section "exploit — frameworks & bases d'exploits"
  apt_pkgs metasploit-framework exploitdb
  have searchsploit && $SUDO searchsploit -u >>"$INSTALL_LOG" 2>&1 || true
fi

if in_group shells; then
  section "shells — reverse shells & interaction"
  apt_pkgs netcat-traditional socat evil-winrm
  pipx_install pwncat-cs pwncat-cs
fi

if in_group privesc; then
  section "privesc — élévation de privilèges"
  apt_pkgs peass linux-exploit-suggester pspy 2>/dev/null || true
  # peass-ng scripts (linpeas/winpeas) : on garantit une copie locale à jour
  git_clone_opt "https://github.com/peass-ng/PEASS-ng.git" "PEASS-ng"
  git_clone_opt "https://github.com/DominicBreuker/pspy.git" "pspy"
  ok "linpeas : /opt/PEASS-ng/linPEAS/  |  winpeas : /opt/PEASS-ng/winPEAS/"
fi

if in_group pivot; then
  section "pivot — tunneling & pivoting"
  apt_pkgs proxychains4 sshuttle chisel
  # ligolo-ng (proxy/agent) via releases GitHub
  if ! have ligolo-proxy; then
    log "Installation de ligolo-ng…"
    tmp="$(mktemp -d)"
    base="https://github.com/nicocha30/ligolo-ng/releases/download/v${LIGOLO_VERSION}"
    if curl -fsSL -o "$tmp/proxy.tgz" "$base/ligolo-ng_proxy_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1; then
      tar -xzf "$tmp/proxy.tgz" -C "$tmp" >>"$INSTALL_LOG" 2>&1
      $SUDO install -m755 "$tmp/proxy" /usr/local/bin/ligolo-proxy 2>>"$INSTALL_LOG" && INSTALLED_OK+=("ligolo-proxy")
      # agent (à transférer sur la cible)
      curl -fsSL -o "$tmp/agent.tgz" "$base/ligolo-ng_agent_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1 \
        && tar -xzf "$tmp/agent.tgz" -C "$tmp" >>"$INSTALL_LOG" 2>&1 \
        && $SUDO install -m755 "$tmp/agent" /usr/local/bin/ligolo-agent 2>>"$INSTALL_LOG" && ok "ligolo-agent -> /usr/local/bin/ligolo-agent (à copier sur la cible)"
    else
      warn "ligolo-ng : échec du téléchargement."; INSTALLED_FAIL+=("ligolo-ng")
    fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("ligolo-ng"); fi
fi

if in_group wordlists; then
  section "wordlists — dictionnaires"
  apt_pkgs seclists wordlists
  # rockyou
  if [[ -f /usr/share/wordlists/rockyou.txt.gz && ! -f /usr/share/wordlists/rockyou.txt ]]; then
    $SUDO gunzip -k /usr/share/wordlists/rockyou.txt.gz >>"$INSTALL_LOG" 2>&1 && ok "rockyou.txt décompressé"
  fi
  ok "SecLists : /usr/share/seclists/"
fi

print_summary

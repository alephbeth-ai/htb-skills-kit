#!/usr/bin/env bash
# ==============================================================================
# install-ubuntu.sh — Outils HTB principaux pour Ubuntu / Debian (OpenClaw)
# ------------------------------------------------------------------------------
# Ubuntu ne dispose pas des dépôts Kali. Ce script installe les outils depuis :
#   - apt (dépôts universe)
#   - pipx (outils Python isolés)
#   - go install (outils ProjectDiscovery, etc.)
#   - releases GitHub (.deb / binaires) pour ce qui n'existe pas ailleurs
#
# On N'AJOUTE PAS les dépôts Kali à Ubuntu (risque de casser le système).
#
# Usage :
#   chmod +x install-ubuntu.sh && ./install-ubuntu.sh          # tout
#   ./install-ubuntu.sh core web ad                            # groupes ciblés
#   ./install-ubuntu.sh --list
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
${C_BOLD}install-ubuntu.sh${C_RESET} — installe les outils HTB sur Ubuntu/Debian

Usage : $0 [groupes...]   (aucun argument = tous les groupes)

Groupes :
  core       git, python3, pipx, go, build-essential, jq, nettools, seclists deps
  recon      nmap, masscan, rustscan(.deb), autorecon(pipx)
  web        gobuster(go), ffuf(go), feroxbuster(.deb), nikto, whatweb, wpscan,
             httpx/subfinder/nuclei(go), dirsearch(pipx)
  smb        smbclient, smbmap(pipx), enum4linux-ng(pipx), impacket(pipx),
             netexec(pipx), ldap-utils, ldapdomaindump(pipx)
  ad         bloodhound.py(pipx), neo4j(apt), kerbrute(go), certipy(pipx),
             evil-winrm(gem), netexec(pipx)
  passwords  hydra, john, hashcat, hash-identifier(pipx), cewl(gem), medusa
  exploit    metasploit(installer officiel), exploitdb/searchsploit(git)
  shells     netcat, socat, pwncat-cs(pipx), evil-winrm(gem)
  privesc    PEASS-ng(git linpeas/winpeas), pspy(git), les(git)
  pivot      proxychains4, sshuttle, chisel(.bin), ligolo-ng(.bin)
  wordlists  SecLists(git), rockyou

Options :
  --list, -h/--help
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list) printf '%s\n' "${GROUPS_ALL[@]}"; exit 0 ;;
esac
[[ $# -eq 0 ]] && GROUPS=("${GROUPS_ALL[@]}") || GROUPS=("$@")

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
require_sudo
section "Mise à jour des dépôts + activation de 'universe'"
$SUDO apt-get update -y >>"$INSTALL_LOG" 2>&1 || warn "apt update a renvoyé une erreur"
if have add-apt-repository; then
  $SUDO add-apt-repository -y universe >>"$INSTALL_LOG" 2>&1 || true
  $SUDO apt-get update -y >>"$INSTALL_LOG" 2>&1 || true
fi

in_group() { local g; for g in "${GROUPS[@]}"; do [[ "$g" == "$1" ]] && return 0; done; return 1; }

# S'assure que Go et pipx sont là si un groupe non-core en a besoin
ensure_toolchain() {
  have go   || apt_pkgs golang-go
  have pipx || { apt_pkgs pipx || apt_pkgs python3-pip; have pipx || $SUDO python3 -m pip install --break-system-packages pipx >>"$INSTALL_LOG" 2>&1 || true; }
  export PATH="$PATH:$HOME/go/bin:/usr/local/bin"
}

# ============================================================================
if in_group core; then
  section "core — bases système et langages"
  apt_pkgs git curl wget build-essential python3 python3-pip python3-venv pipx \
           golang-go jq net-tools dnsutils vim tmux unzip ripgrep gcc make \
           libssl-dev ruby ruby-dev
  pipx ensurepath >>"$INSTALL_LOG" 2>&1 || true
  export PATH="$PATH:$HOME/.local/bin:$HOME/go/bin:/usr/local/bin"
fi

if in_group recon; then
  section "recon — découverte & scan"
  ensure_toolchain
  apt_pkgs nmap masscan
  pipx_install "git+https://github.com/Tib3rius/AutoRecon.git" autorecon
  if ! have rustscan; then
    log "rustscan (.deb GitHub)…"
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/rs.deb" "https://github.com/RustScan/RustScan/releases/download/${RUSTSCAN_VERSION}/rustscan_${RUSTSCAN_VERSION}_amd64.deb" >>"$INSTALL_LOG" 2>&1 \
       && $SUDO dpkg -i "$tmp/rs.deb" >>"$INSTALL_LOG" 2>&1; then INSTALLED_OK+=("rustscan"); else warn "rustscan échec"; INSTALLED_FAIL+=("rustscan"); fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("rustscan"); fi
fi

if in_group web; then
  section "web — énumération & fuzzing"
  ensure_toolchain
  apt_pkgs nikto whatweb dirb wfuzz
  go_install "github.com/OJ/gobuster/v3@latest" gobuster
  go_install "github.com/ffuf/ffuf/v2@latest" ffuf
  go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest" httpx
  go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" subfinder
  go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" nuclei
  pipx_install dirsearch dirsearch
  # feroxbuster (.deb officiel)
  if ! have feroxbuster; then
    log "feroxbuster…"
    tmp="$(mktemp -d)"
    if curl -fsSL "https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh" -o "$tmp/f.sh" >>"$INSTALL_LOG" 2>&1 \
       && $SUDO bash "$tmp/f.sh" /usr/local/bin >>"$INSTALL_LOG" 2>&1; then INSTALLED_OK+=("feroxbuster"); else warn "feroxbuster échec"; INSTALLED_FAIL+=("feroxbuster"); fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("feroxbuster"); fi
  # wpscan (gem)
  if ! have wpscan; then have gem && ($SUDO gem install wpscan >>"$INSTALL_LOG" 2>&1 && INSTALLED_OK+=("wpscan") || { warn "wpscan échec"; INSTALLED_FAIL+=("wpscan"); }); fi
fi

if in_group smb; then
  section "smb — services réseau"
  ensure_toolchain
  apt_pkgs smbclient ldap-utils snmp onesixtyone
  pipx_install impacket impacket
  pipx_install smbmap smbmap
  pipx_install "git+https://github.com/cddmp/enum4linux-ng.git" enum4linux-ng
  pipx_install ldapdomaindump ldapdomaindump
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
fi

if in_group ad; then
  section "ad — Active Directory"
  ensure_toolchain
  apt_pkgs neo4j
  pipx_install "git+https://github.com/dirkjanm/BloodHound.py.git" bloodhound-python
  pipx_install certipy-ad certipy-ad
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
  go_install "github.com/ropnop/kerbrute@latest" kerbrute
  if ! have evil-winrm; then have gem && ($SUDO gem install evil-winrm >>"$INSTALL_LOG" 2>&1 && INSTALLED_OK+=("evil-winrm") || { warn "evil-winrm échec"; INSTALLED_FAIL+=("evil-winrm"); }); fi
  warn "BloodHound GUI : installez l'app depuis github.com/SpecterOps/BloodHound (Docker conseillé). Ici seul le collector Python est posé."
fi

if in_group passwords; then
  section "passwords — brute force & cracking"
  ensure_toolchain
  apt_pkgs hydra john hashcat medusa
  pipx_install hash-id hash-id 2>/dev/null || true
  if ! have cewl; then have gem && ($SUDO gem install cewl >>"$INSTALL_LOG" 2>&1 && INSTALLED_OK+=("cewl") || true); fi
fi

if in_group exploit; then
  section "exploit — Metasploit & searchsploit"
  # Metasploit : installeur officiel Rapid7 (nightly), pas de dépôt apt sur Ubuntu
  if ! have msfconsole; then
    log "Metasploit (installeur officiel Rapid7)…"
    tmp="$(mktemp)"
    if curl -fsSL "https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb" -o "$tmp" >>"$INSTALL_LOG" 2>&1 \
       && $SUDO chmod 755 "$tmp" && $SUDO "$tmp" >>"$INSTALL_LOG" 2>&1; then INSTALLED_OK+=("metasploit"); else warn "metasploit échec (voir log)"; INSTALLED_FAIL+=("metasploit"); fi
    rm -f "$tmp"
  else INSTALLED_SKIP+=("metasploit"); fi
  # exploitdb / searchsploit
  git_clone_opt "https://gitlab.com/exploit-database/exploitdb.git" "exploitdb"
  [[ -f /opt/exploitdb/searchsploit ]] && $SUDO ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit && ok "searchsploit -> /usr/local/bin"
fi

if in_group shells; then
  section "shells — reverse shells & interaction"
  ensure_toolchain
  apt_pkgs netcat-traditional socat
  pipx_install pwncat-cs pwncat-cs
  if ! have evil-winrm; then have gem && ($SUDO gem install evil-winrm >>"$INSTALL_LOG" 2>&1 && INSTALLED_OK+=("evil-winrm") || true); fi
fi

if in_group privesc; then
  section "privesc — élévation de privilèges"
  git_clone_opt "https://github.com/peass-ng/PEASS-ng.git" "PEASS-ng"
  git_clone_opt "https://github.com/DominicBreuker/pspy.git" "pspy"
  git_clone_opt "https://github.com/The-Z-Labs/linux-exploit-suggester.git" "linux-exploit-suggester"
  ok "linpeas : /opt/PEASS-ng/linPEAS/  |  winpeas : /opt/PEASS-ng/winPEAS/  |  LES : /opt/linux-exploit-suggester/"
fi

if in_group pivot; then
  section "pivot — tunneling & pivoting"
  apt_pkgs proxychains4 sshuttle
  # chisel (binaire GitHub)
  if ! have chisel; then
    log "chisel…"
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/chisel.gz" "https://github.com/jpillora/chisel/releases/download/v${CHISEL_VERSION}/chisel_${CHISEL_VERSION}_linux_${ARCH}.gz" >>"$INSTALL_LOG" 2>&1 \
       && gunzip "$tmp/chisel.gz" && $SUDO install -m755 "$tmp/chisel" /usr/local/bin/chisel; then INSTALLED_OK+=("chisel"); else warn "chisel échec"; INSTALLED_FAIL+=("chisel"); fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("chisel"); fi
  # ligolo-ng
  if ! have ligolo-proxy; then
    log "ligolo-ng…"
    tmp="$(mktemp -d)"; base="https://github.com/nicocha30/ligolo-ng/releases/download/v${LIGOLO_VERSION}"
    if curl -fsSL -o "$tmp/p.tgz" "$base/ligolo-ng_proxy_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1; then
      tar -xzf "$tmp/p.tgz" -C "$tmp" && $SUDO install -m755 "$tmp/proxy" /usr/local/bin/ligolo-proxy && INSTALLED_OK+=("ligolo-proxy")
      curl -fsSL -o "$tmp/a.tgz" "$base/ligolo-ng_agent_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1 \
        && tar -xzf "$tmp/a.tgz" -C "$tmp" && $SUDO install -m755 "$tmp/agent" /usr/local/bin/ligolo-agent && ok "ligolo-agent posé (à copier sur la cible)"
    else warn "ligolo-ng échec"; INSTALLED_FAIL+=("ligolo-ng"); fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("ligolo-proxy"); fi
fi

if in_group wordlists; then
  section "wordlists — dictionnaires"
  $SUDO mkdir -p /usr/share/wordlists
  git_clone_opt "https://github.com/danielmiessler/SecLists.git" "SecLists"
  [[ -d /opt/SecLists ]] && $SUDO ln -sfn /opt/SecLists /usr/share/seclists && ok "SecLists -> /usr/share/seclists"
  # rockyou depuis SecLists
  if [[ -f /opt/SecLists/Passwords/Leaked-Databases/rockyou.txt.tar.gz && ! -f /usr/share/wordlists/rockyou.txt ]]; then
    $SUDO tar -xzf /opt/SecLists/Passwords/Leaked-Databases/rockyou.txt.tar.gz -C /usr/share/wordlists >>"$INSTALL_LOG" 2>&1 && ok "rockyou.txt -> /usr/share/wordlists/"
  fi
fi

print_summary
echo
warn "Pensez à recharger votre shell (source ~/.bashrc) pour que ~/.local/bin et ~/go/bin soient dans le PATH."

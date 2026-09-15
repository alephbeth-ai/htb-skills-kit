#!/usr/bin/env bash
# ==============================================================================
# install-kali.sh — Main HTB tools for Kali Linux (OpenClaw)
# ------------------------------------------------------------------------------
# Kali already ships most of the tools. This script ensures they are
# present, adds useful metapackages and installs the modern tools
# (netexec, ligolo-ng, feroxbuster, subfinder, etc.) missing by default.
#
# Usage:
#   chmod +x install-kali.sh && ./install-kali.sh            # everything
#   ./install-kali.sh core web ad                            # targeted groups
#   ./install-kali.sh --list                                 # list the groups
#
# ⚠️  Legal use only: Hack The Box, labs, CTF, authorized systems.
# ==============================================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

GROUPS_ALL=(core recon web smb ad passwords exploit shells privesc pivot wordlists)

usage() {
  cat <<EOF
${C_BOLD}install-kali.sh${C_RESET} — installs the HTB tools on Kali Linux

Usage: $0 [groups...]   (no argument = all groups)

Available groups:
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

Options:
  --list     print the groups then exit
  -h,--help  this help
EOF
}

# --- Argument parsing --------------------------------------------------------
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --list) printf '%s\n' "${GROUPS_ALL[@]}"; exit 0 ;;
esac
if [[ $# -eq 0 ]]; then
  GROUPS=("${GROUPS_ALL[@]}")
else
  GROUPS=("$@")
fi

# --- OS check ---------------------------------------------------------------
if ! grep -qi kali /etc/os-release 2>/dev/null; then
  warn "System not identified as Kali. Use install-ubuntu.sh instead on Debian/Ubuntu."
  read -rp "Continue anyway? [y/N] " r; [[ "$r" =~ ^[Yy]$ ]] || exit 1
fi

require_sudo
section "Updating repositories"
$SUDO apt-get update -y >>"$INSTALL_LOG" 2>&1 || warn "apt update returned an error (see log)"

in_group() { local g; for g in "${GROUPS[@]}"; do [[ "$g" == "$1" ]] && return 0; done; return 1; }

# ============================================================================
# GROUPES
# ============================================================================

if in_group core; then
  section "core — system basics and languages"
  apt_pkgs git curl wget build-essential python3 python3-pip python3-venv pipx \
           golang-go jq net-tools dnsutils vim tmux unzip ripgrep
  pipx ensurepath >>"$INSTALL_LOG" 2>&1 || true
fi

if in_group recon; then
  section "recon — discovery & scanning"
  apt_pkgs nmap masscan autorecon
  # rustscan: official .deb package (not in the default repositories)
  if ! have rustscan; then
    log "Installing rustscan (.deb from GitHub)…"
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/rustscan.deb" \
        "https://github.com/RustScan/RustScan/releases/download/${RUSTSCAN_VERSION}/rustscan_${RUSTSCAN_VERSION}_amd64.deb" >>"$INSTALL_LOG" 2>&1 \
        && $SUDO dpkg -i "$tmp/rustscan.deb" >>"$INSTALL_LOG" 2>&1; then
      INSTALLED_OK+=("rustscan")
    else
      warn "rustscan: .deb install failed, cargo/go attempt skipped."; INSTALLED_FAIL+=("rustscan")
    fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("rustscan"); fi
fi

if in_group web; then
  section "web — enumeration & fuzzing"
  apt_pkgs ffuf feroxbuster gobuster nikto whatweb wpscan dirb dirsearch wfuzz
  go_install "github.com/projectdiscovery/httpx/cmd/httpx@latest" httpx
  go_install "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" subfinder
  go_install "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" nuclei
fi

if in_group smb; then
  section "smb — Windows/Unix network services"
  apt_pkgs smbclient smbmap enum4linux enum4linux-ng ldap-utils rpcbind \
           python3-impacket ldapdomaindump onesixtyone snmp
  # netexec (successor of crackmapexec)
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
fi

if in_group ad; then
  section "ad — Active Directory"
  apt_pkgs bloodhound neo4j kerbrute evil-winrm
  pipx_install certipy-ad certipy-ad
  pipx_install "git+https://github.com/Pennyw0rth/NetExec" netexec
  warn "BloodHound: start neo4j with 'sudo neo4j console' (default credentials neo4j/neo4j)."
fi

if in_group passwords; then
  section "passwords — brute force & cracking"
  apt_pkgs hydra john hashcat hash-identifier cewl crackmapexec medusa
fi

if in_group exploit; then
  section "exploit — frameworks & exploit databases"
  apt_pkgs metasploit-framework exploitdb
  have searchsploit && $SUDO searchsploit -u >>"$INSTALL_LOG" 2>&1 || true
fi

if in_group shells; then
  section "shells — reverse shells & interaction"
  apt_pkgs netcat-traditional socat evil-winrm
  pipx_install pwncat-cs pwncat-cs
fi

if in_group privesc; then
  section "privesc — privilege escalation"
  apt_pkgs peass linux-exploit-suggester pspy 2>/dev/null || true
  # peass-ng scripts (linpeas/winpeas): ensure an up-to-date local copy
  git_clone_opt "https://github.com/peass-ng/PEASS-ng.git" "PEASS-ng"
  git_clone_opt "https://github.com/DominicBreuker/pspy.git" "pspy"
  ok "linpeas : /opt/PEASS-ng/linPEAS/  |  winpeas : /opt/PEASS-ng/winPEAS/"
fi

if in_group pivot; then
  section "pivot — tunneling & pivoting"
  apt_pkgs proxychains4 sshuttle chisel
  # ligolo-ng (proxy/agent) via GitHub releases
  if ! have ligolo-proxy; then
    log "Installing ligolo-ng…"
    tmp="$(mktemp -d)"
    base="https://github.com/nicocha30/ligolo-ng/releases/download/v${LIGOLO_VERSION}"
    if curl -fsSL -o "$tmp/proxy.tgz" "$base/ligolo-ng_proxy_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1; then
      tar -xzf "$tmp/proxy.tgz" -C "$tmp" >>"$INSTALL_LOG" 2>&1
      $SUDO install -m755 "$tmp/proxy" /usr/local/bin/ligolo-proxy 2>>"$INSTALL_LOG" && INSTALLED_OK+=("ligolo-proxy")
      # agent (to transfer onto the target)
      curl -fsSL -o "$tmp/agent.tgz" "$base/ligolo-ng_agent_${LIGOLO_VERSION}_linux_amd64.tar.gz" >>"$INSTALL_LOG" 2>&1 \
        && tar -xzf "$tmp/agent.tgz" -C "$tmp" >>"$INSTALL_LOG" 2>&1 \
        && $SUDO install -m755 "$tmp/agent" /usr/local/bin/ligolo-agent 2>>"$INSTALL_LOG" && ok "ligolo-agent -> /usr/local/bin/ligolo-agent (to copy onto the target)"
    else
      warn "ligolo-ng: download failed."; INSTALLED_FAIL+=("ligolo-ng")
    fi
    rm -rf "$tmp"
  else INSTALLED_SKIP+=("ligolo-ng"); fi
fi

if in_group wordlists; then
  section "wordlists — dictionaries"
  apt_pkgs seclists wordlists
  # rockyou
  if [[ -f /usr/share/wordlists/rockyou.txt.gz && ! -f /usr/share/wordlists/rockyou.txt ]]; then
    $SUDO gunzip -k /usr/share/wordlists/rockyou.txt.gz >>"$INSTALL_LOG" 2>&1 && ok "rockyou.txt decompressed"
  fi
  ok "SecLists : /usr/share/seclists/"
fi

print_summary

---
name: htb-recon
description: >
  Target discovery and port/service scanning against a Hack The Box box or an
  authorized lab. Trigger this at the very start of an engagement, when you have
  a target IP and nothing else: ping/host discovery, port scanning (nmap,
  rustscan, masscan), version and service detection, NSE script scanning.
  Produces the list of open ports and the services to enumerate next.
metadata:
  type: reference
  category: reconnaissance
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Reconnaissance & port scanning

## When to use this skill
First step on any box: you have an IP (`$IP`) and need to map the attack surface.
Goal: list the open ports and identify each service with its version.

## Safeguard
Only act on explicitly authorized targets. On HTB, that is the IP of the assigned
machine. Never scan an IP outside the scope.

## Recommended workflow
1. **Fast scan of all ports** to find what is open.
2. **Deep scan** (versions + scripts) on the ports found.
3. **Targeted UDP scan** on the usual classics if TCP is thin.
4. Record the results and chain into the service enumeration skill.

## Reference commands

```bash
IP=10.10.10.10

# 1) Fast: all TCP ports (rustscan feeds nmap)
rustscan -a "$IP" --ulimit 5000 -- -sV

# nmap-only equivalent, all ports:
nmap -p- --min-rate 5000 -T4 "$IP" -oN nmap-allports.txt

# 2) Deep scan on the open ports (replace the list)
nmap -sC -sV -p 22,80,445 "$IP" -oN nmap-deep.txt

# 3) UDP top-ports (slow, target it)
sudo nmap -sU --top-ports 50 "$IP" -oN nmap-udp.txt

# 4) Vuln NSE scripts (use with care)
nmap --script vuln -p 80,445 "$IP" -oN nmap-vuln.txt
```

## Reading the results → next skill
| Open port(s) | Service | Skill to chain into |
|---|---|---|
| 80, 443, 8080, 8000 | HTTP(S) | `htb-web-enum` |
| 445, 139 | SMB | `htb-smb-enum` |
| 389, 636, 88, 5985 | LDAP/Kerberos/WinRM | `htb-active-directory` |
| 21 | FTP | try `anonymous`, list |
| 22 | SSH | note the version, keep for later |
| 25, 110, 143 | mail | enumerate users (VRFY, etc.) |

## Tips
- Always keep the `-oN`/`-oA` outputs: an agent needs to re-parse the ports.
- If `nmap -p-` is very slow, use `masscan -p1-65535 $IP --rate 1000` then a targeted nmap.
- Add discovered hostnames (e.g. `machine.htb`) to `/etc/hosts`.

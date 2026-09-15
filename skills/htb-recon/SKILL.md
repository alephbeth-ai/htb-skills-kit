---
name: htb-recon
description: >
  Découverte de cibles et scan de ports/services sur une box Hack The Box ou un
  lab autorisé. À déclencher au tout début d'un engagement, quand on a une IP
  cible et rien d'autre : ping/host discovery, scan de ports (nmap, rustscan,
  masscan), détection de versions et de services, scan de scripts NSE. Produit la
  liste des ports ouverts et des services à énumérer ensuite.
metadata:
  type: reference
  category: reconnaissance
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Reconnaissance & scan de ports

## Quand utiliser cette skill
Première étape sur toute box : vous avez une IP (`$IP`) et devez cartographier
la surface d'attaque. Objectif : lister les ports ouverts et identifier chaque
service avec sa version.

## Garde-fou
N'agir que sur des cibles explicitement autorisées. Sur HTB, c'est l'IP de la
machine assignée. Ne jamais scanner une IP hors périmètre.

## Workflow recommandé
1. **Scan rapide de tous les ports** pour trouver ce qui est ouvert.
2. **Scan approfondi** (versions + scripts) sur les ports trouvés.
3. **Scan UDP ciblé** sur les grands classiques si TCP est pauvre.
4. Consigner les résultats et enchaîner sur la skill d'énumération du service.

## Commandes de référence

```bash
IP=10.10.10.10

# 1) Rapide : tous les ports TCP (rustscan alimente nmap)
rustscan -a "$IP" --ulimit 5000 -- -sV

# Équivalent nmap seul, tous les ports :
nmap -p- --min-rate 5000 -T4 "$IP" -oN nmap-allports.txt

# 2) Approfondi sur les ports ouverts (remplacer la liste)
nmap -sC -sV -p 22,80,445 "$IP" -oN nmap-deep.txt

# 3) UDP top-ports (lent, cibler)
sudo nmap -sU --top-ports 50 "$IP" -oN nmap-udp.txt

# 4) Vuln scripts NSE (avec prudence)
nmap --script vuln -p 80,445 "$IP" -oN nmap-vuln.txt
```

## Lecture des résultats → skill suivante
| Port(s) ouverts | Service | Skill à enchaîner |
|---|---|---|
| 80, 443, 8080, 8000 | HTTP(S) | `htb-web-enum` |
| 445, 139 | SMB | `htb-smb-enum` |
| 389, 636, 88, 5985 | LDAP/Kerberos/WinRM | `htb-active-directory` |
| 21 | FTP | tester `anonymous`, lister |
| 22 | SSH | noter la version, garder pour plus tard |
| 25, 110, 143 | mail | énumérer users (VRFY, etc.) |

## Astuces
- Toujours garder les sorties `-oN`/`-oA` : un agent doit re-parser les ports.
- Si `nmap -p-` est très lent, `masscan -p1-65535 $IP --rate 1000` puis nmap ciblé.
- Ajouter les hostnames découverts (ex. `machine.htb`) dans `/etc/hosts`.

# SKILLs HTB pour agent IA (OpenClaw)

Bibliothèque de compétences que l'agent charge selon la phase de l'engagement.
Chaque dossier contient un `SKILL.md` (frontmatter `name` + `description`, puis
procédure et commandes). L'agent choisit la skill via la `description`.

## Orchestration (à charger en premier)

**[htb-workflow](htb-workflow/SKILL.md)** est le chef d'orchestre : il mappe chaque
phase sur les tactiques **MITRE ATT&CK**, décide quelle skill appeler ensuite, et
définit le format des fichiers d'état partagés (`creds.txt`, `notes.md`). L'agent
le charge au début de la box, puis délègue aux skills spécialisées ci-dessous.
En fin de box, il génère un **rapport ATT&CK Navigator** (layer JSON importable)
via `htb-workflow/gen-navigator-layer.py`.

## Ordre logique d'un engagement HTB

```
                         ┌──────────────┐
                         │ htb-workflow │  (orchestrateur, MITRE ATT&CK)
                         └──────┬───────┘
                                ▼
htb-preflight ──► htb-recon ──► htb-web-enum ─┐
(périmètre+VPN)             └─► htb-smb-enum ─┼─► htb-exploitation ──► htb-shells ──► htb-privesc
                            └─► htb-active-directory ┘                                     │
                                                                                           ▼
                               htb-password-attacks (transverse)    htb-pivoting ──► htb-report
                                                                  (labs multi)   (rapport + ATT&CK layer)
```

## Index des skills

| Skill | Déclencheur | Rôle |
|---|---|---|
| [htb-workflow](htb-workflow/SKILL.md) | Début de box / "quoi faire ensuite ?" | Orchestrateur aligné MITRE ATT&CK, état partagé |
| [htb-preflight](htb-preflight/SKILL.md) | Avant toute action | Contrôle périmètre + VPN (tun0), fixe IP/LHOST |
| [htb-recon](htb-recon/SKILL.md) | IP cible, début de box | Scan ports/services (nmap, rustscan, masscan) |
| [htb-web-enum](htb-web-enum/SKILL.md) | Port 80/443/8080 ouvert | Fuzzing, vhosts, CMS (ffuf, feroxbuster, wpscan) |
| [htb-smb-enum](htb-smb-enum/SKILL.md) | Port 445/139/389 | Partages, users, null session (netexec, enum4linux-ng) |
| [htb-active-directory](htb-active-directory/SKILL.md) | Domain Controller / domaine .htb | Kerberoast, BloodHound, PtH, DCSync |
| [htb-password-attacks](htb-password-attacks/SKILL.md) | Hash ou service d'auth | Craquage & brute force (hashcat, john, hydra) |
| [htb-exploitation](htb-exploitation/SKILL.md) | Service + version connus | Exploit public / Metasploit → foothold |
| [htb-shells](htb-shells/SKILL.md) | RCE / injection obtenue | Reverse shell + stabilisation TTY |
| [htb-privesc](htb-privesc/SKILL.md) | Shell non privilégié | Escalade root/SYSTEM (linpeas, GTFOBins) |
| [htb-pivoting](htb-pivoting/SKILL.md) | Réseau interne inaccessible | Tunnels (ligolo-ng, chisel, proxychains) |
| [htb-report](htb-report/SKILL.md) | Flags obtenus, fin de box | Rapport Markdown -> PDF + annexe ATT&CK Navigator |

## Convention

- `LHOST` / IP d'attaque = l'interface VPN HTB (`tun0`), jamais `eth0`.
- Chaque credential trouvé va dans un `creds.txt` et est rejoué partout (reuse).
- Les sorties d'outils sont sauvegardées (`-oN`, `-o`) pour re-parsing par l'agent.

## Cadre légal

Ces skills décrivent des techniques offensives destinées **exclusivement** à des
cibles autorisées : machines Hack The Box assignées, labs personnels, CTF, et
systèmes dont vous avez la propriété ou l'autorisation écrite de test. Toute
utilisation hors de ce cadre est interdite.

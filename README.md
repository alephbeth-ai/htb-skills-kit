# Claude-HTB-SKILL — Boîte à outils HTB + SKILLs agent IA (OpenClaw)

Deux livrables pour préparer un poste de pentest Hack The Box et piloter un agent
IA (OpenClaw) sur ces outils :

1. **Scripts d'installation Bash** (`install/`) — posent les principaux outils HTB
   sur **Kali** et sur **Ubuntu/Debian**.
2. **Bibliothèque de SKILLs** (`skills/`) — 12 compétences que l'agent IA charge
   selon la phase de l'engagement, orchestrées par `htb-workflow` (aligné MITRE
   ATT&CK) : preflight → recon → exploit → privesc → pivot → report.
3. **Outils d'exploitation** (`install/check-tools.sh`, `install/update-tools.sh`,
   `bin/new-box.sh`) — vérifier l'environnement, suivre les versions, et préparer
   un dossier d'engagement par box.

> ⚠️ **Usage légal uniquement.** Tout ce dépôt vise des cibles autorisées :
> machines HTB assignées, labs personnels, CTF, systèmes dont vous avez
> l'autorisation de test. Rien d'autre.

## Arborescence

```
Claude-HTB-SKILL/
├── .github/workflows/ci.yml   # CI : shellcheck + lint python + validation
├── .shellcheckrc              # config ShellCheck (external-sources, exceptions)
├── tools/validate.py          # valide frontmatter des skills + layer ATT&CK
├── install/
│   ├── install-kali.sh        # Kali : garantit + ajoute les outils modernes
│   ├── install-ubuntu.sh      # Ubuntu/Debian : tout depuis apt/pipx/go/GitHub
│   ├── check-tools.sh         # healthcheck : quels outils sont présents/absents
│   ├── update-tools.sh        # compare aux dernières releases / git pull /opt
│   ├── versions.env           # versions épinglées (source unique de vérité)
│   └── lib/common.sh          # helpers partagés (log, apt, pipx, go, résumé)
├── bin/
│   └── new-box.sh             # scaffolding d'un dossier d'engagement par box
├── skills/
│   ├── README.md              # index + ordre logique des skills
│   ├── htb-preflight/SKILL.md # contrôle périmètre + VPN (tun0), à lancer en 1er
│   ├── htb-workflow/          # orchestrateur (MITRE ATT&CK)
│   │   ├── SKILL.md
│   │   ├── gen-navigator-layer.py            # génère le rapport ATT&CK Navigator
│   │   ├── techniques.example.txt            # entrée exemple du générateur
│   │   └── attack-navigator-layer.template.json  # layer modèle importable
│   ├── htb-report/SKILL.md    # rapport final Markdown -> PDF (fin de box)
│   ├── htb-recon/SKILL.md
│   ├── htb-web-enum/SKILL.md
│   ├── htb-smb-enum/SKILL.md
│   ├── htb-active-directory/SKILL.md
│   ├── htb-password-attacks/SKILL.md
│   ├── htb-exploitation/SKILL.md
│   ├── htb-shells/SKILL.md
│   ├── htb-privesc/SKILL.md
│   └── htb-pivoting/SKILL.md
└── README.md
```

## Installation

Les scripts sont **idempotents** (relançables) et **modulaires** (installation par
groupes). Transférez le dossier `install/` sur la machine Linux cible.

```bash
# Kali — tout
chmod +x install/install-kali.sh install/lib/common.sh
./install/install-kali.sh

# Ubuntu/Debian — tout
chmod +x install/install-ubuntu.sh install/lib/common.sh
./install/install-ubuntu.sh

# Groupes ciblés (ex. seulement web + AD)
./install/install-ubuntu.sh web ad

# Lister les groupes
./install/install-kali.sh --list
```

Groupes disponibles : `core recon web smb ad passwords exploit shells privesc pivot wordlists`.

Un journal détaillé est écrit dans `/tmp/htb-install-<date>.log`, et un résumé
(installés / déjà présents / échecs) s'affiche à la fin.

### Ce qui est installé (aperçu)

| Domaine | Outils |
|---|---|
| Recon | nmap, masscan, rustscan, autorecon |
| Web | ffuf, feroxbuster, gobuster, nikto, whatweb, wpscan, httpx, subfinder, nuclei, dirsearch |
| SMB/AD | netexec, enum4linux-ng, smbmap, impacket, bloodhound(.py), kerbrute, certipy, evil-winrm, ldapdomaindump |
| Passwords | hydra, john, hashcat, hash-identifier, cewl, medusa |
| Exploit | metasploit, searchsploit (exploitdb) |
| Shells | netcat, socat, pwncat-cs |
| Privesc | PEASS-ng (linpeas/winpeas), pspy, linux-exploit-suggester |
| Pivot | ligolo-ng, chisel, proxychains4, sshuttle |
| Wordlists | SecLists, rockyou |

### Différences Kali vs Ubuntu
- **Kali** : la majorité vient des dépôts Kali (`apt`) ; le script complète avec
  netexec, ligolo-ng, rustscan et les scripts PEASS.
- **Ubuntu** : pas de dépôts Kali (on ne les ajoute pas, c'est risqué). Tout passe
  par `apt` (universe), `pipx`, `go install`, `gem` et des releases GitHub. Après
  installation, rechargez le shell : `source ~/.bashrc` (pour `~/.local/bin` et `~/go/bin`).

## Outils d'exploitation

```bash
# Vérifier ce qui est installé (code de sortie ≠ 0 si manquants -> utile en CI)
./install/check-tools.sh            # tous les groupes
./install/check-tools.sh web ad     # groupes ciblés

# Suivre les versions épinglées (versions.env) vs dernières releases GitHub
./install/update-tools.sh --check
./install/update-tools.sh --pull    # git pull des dépôts clonés dans /opt

# Préparer un dossier d'engagement (notes.md, creds.txt, techniques.txt, scans/…)
./bin/new-box.sh "Forest" 10.10.10.161 forest.htb --hosts
#   -> crée ~/htb/forest/ (variable HTB_DIR pour changer la base)
```

Les versions des binaires GitHub sont centralisées dans
[`install/versions.env`](install/versions.env) : un seul fichier à éditer pour
mettre à jour rustscan, ligolo-ng ou chisel.

## Qualité / Intégration continue

Un workflow GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml))
s'exécute à chaque push / pull request et lance trois jobs :

| Job | Contrôle |
|---|---|
| **shellcheck** | Lint de tous les scripts `.sh` (config dans `.shellcheckrc`) + `bash -n` |
| **python** | Lint `ruff` + compilation du générateur ATT&CK et du validateur |
| **validate** | Frontmatter des `SKILL.md`, layer JSON, exécution de `gen-navigator-layer.py` |

Reproduire les contrôles localement :

```bash
# Validation skills + layer ATT&CK (nécessite pyyaml)
python tools/validate.py

# ShellCheck (si installé)
find . -name '*.sh' | xargs shellcheck --severity=warning
```

> La CI ne se déclenche qu'une fois le dossier poussé sur un dépôt GitHub
> (`git init`, commit, push). Le workflow tourne sur `ubuntu-latest`.

## SKILLs pour l'agent IA

Voir [skills/README.md](skills/README.md) pour l'index et l'ordre logique.
Format Claude Skill standard : chaque `SKILL.md` a un frontmatter `name` +
`description` (utilisée par l'agent pour décider de la pertinence), puis une
procédure avec commandes prêtes à l'emploi et des « réflexes » d'enchaînement
vers la skill suivante.

Pour les utiliser avec Claude Code / un agent : placez le dossier `skills/`
là où l'agent découvre ses skills (par ex. `~/.claude/skills/`), ou pointez la
configuration de l'agent vers ce répertoire.

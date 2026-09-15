# Claude-HTB-SKILL — HTB toolkit + AI agent SKILLs (OpenClaw)

Two deliverables to set up a Hack The Box pentest workstation and drive an AI
agent (OpenClaw) with these tools:

1. **Bash install scripts** (`install/`) — lay down the main HTB tools on
   **Kali** and on **Ubuntu/Debian**.
2. **SKILL library** (`skills/`) — 12 skills the AI agent loads according to the
   engagement phase, orchestrated by `htb-workflow` (aligned with MITRE
   ATT&CK): preflight → recon → exploit → privesc → pivot → report.
3. **Operational tools** (`install/check-tools.sh`, `install/update-tools.sh`,
   `bin/new-box.sh`) — check the environment, track versions, and prepare a
   per-box engagement folder.

> ⚠️ **Legal use only.** This entire repository targets authorized systems:
> assigned HTB machines, personal labs, CTFs, and systems you have permission
> to test. Nothing else.

## Directory tree

```
Claude-HTB-SKILL/
├── .github/workflows/ci.yml   # CI: shellcheck + python lint + validation
├── .shellcheckrc              # ShellCheck config (external-sources, exceptions)
├── tools/validate.py          # validates skill frontmatter + ATT&CK layer
├── install/
│   ├── install-kali.sh        # Kali: ensures and adds the modern tools
│   ├── install-ubuntu.sh      # Ubuntu/Debian: everything from apt/pipx/go/GitHub
│   ├── check-tools.sh         # healthcheck: which tools are present/missing
│   ├── update-tools.sh        # compares to latest releases / git pull /opt
│   ├── versions.env           # pinned versions (single source of truth)
│   └── lib/common.sh          # shared helpers (log, apt, pipx, go, summary)
├── bin/
│   └── new-box.sh             # scaffolds a per-box engagement folder
├── skills/
│   ├── README.md              # index + logical order of the skills
│   ├── htb-preflight/SKILL.md # scope + VPN check (tun0), run this first
│   ├── htb-workflow/          # orchestrator (MITRE ATT&CK)
│   │   ├── SKILL.md
│   │   ├── gen-navigator-layer.py            # generates the ATT&CK Navigator report
│   │   ├── techniques.example.txt            # example input for the generator
│   │   └── attack-navigator-layer.template.json  # importable template layer
│   ├── htb-report/SKILL.md    # final Markdown -> PDF report (end of box)
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

The scripts are **idempotent** (safe to re-run) and **modular** (install by
groups). Copy the `install/` folder onto the target Linux machine.

```bash
# Kali — everything
chmod +x install/install-kali.sh install/lib/common.sh
./install/install-kali.sh

# Ubuntu/Debian — everything
chmod +x install/install-ubuntu.sh install/lib/common.sh
./install/install-ubuntu.sh

# Targeted groups (e.g. only web + AD)
./install/install-ubuntu.sh web ad

# List the groups
./install/install-kali.sh --list
```

Available groups: `core recon web smb ad passwords exploit shells privesc pivot wordlists`.

A detailed log is written to `/tmp/htb-install-<date>.log`, and a summary
(installed / already present / failed) is shown at the end.

### What gets installed (overview)

| Domain | Tools |
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

### Kali vs Ubuntu differences
- **Kali**: most tools come from the Kali repositories (`apt`); the script tops
  it off with netexec, ligolo-ng, rustscan and the PEASS scripts.
- **Ubuntu**: no Kali repositories (we don't add them, it's risky). Everything
  goes through `apt` (universe), `pipx`, `go install`, `gem` and GitHub
  releases. After installation, reload the shell: `source ~/.bashrc` (for
  `~/.local/bin` and `~/go/bin`).

## Operational tools

```bash
# Check what is installed (exit code ≠ 0 if missing -> useful in CI)
./install/check-tools.sh            # all groups
./install/check-tools.sh web ad     # targeted groups

# Track pinned versions (versions.env) vs latest GitHub releases
./install/update-tools.sh --check
./install/update-tools.sh --pull    # git pull the repos cloned in /opt

# Prepare an engagement folder (notes.md, creds.txt, techniques.txt, scans/…)
./bin/new-box.sh "Forest" 10.10.10.161 forest.htb --hosts
#   -> creates ~/htb/forest/ (HTB_DIR variable to change the base)
```

The versions of the GitHub binaries are centralized in
[`install/versions.env`](install/versions.env): a single file to edit to update
rustscan, ligolo-ng or chisel.

## Quality / Continuous integration

A GitHub Actions workflow ([.github/workflows/ci.yml](.github/workflows/ci.yml))
runs on every push / pull request and launches three jobs:

| Job | Check |
|---|---|
| **shellcheck** | Lint of every `.sh` script (config in `.shellcheckrc`) + `bash -n` |
| **python** | `ruff` lint + compilation of the ATT&CK generator and the validator |
| **validate** | `SKILL.md` frontmatter, JSON layer, execution of `gen-navigator-layer.py` |

Reproduce the checks locally:

```bash
# Skills + ATT&CK layer validation (requires pyyaml)
python tools/validate.py

# ShellCheck (if installed)
find . -name '*.sh' | xargs shellcheck --severity=warning
```

> CI only triggers once the folder is pushed to a GitHub repository
> (`git init`, commit, push). The workflow runs on `ubuntu-latest`.

## SKILLs for the AI agent

See [skills/README.md](skills/README.md) for the index and the logical order.
Standard Claude Skill format: each `SKILL.md` has a `name` + `description`
frontmatter (used by the agent to decide relevance), then a procedure with
ready-to-use commands and "reflexes" that chain into the next skill.

To use them with Claude Code / an agent: place the `skills/` folder where the
agent discovers its skills (e.g. `~/.claude/skills/`), or point the agent's
configuration at this directory.

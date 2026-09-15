# HTB SKILLs for the AI agent (OpenClaw)

Library of skills the agent loads according to the engagement phase. Each folder
contains a `SKILL.md` (`name` + `description` frontmatter, then procedure and
commands). The agent picks the skill via the `description`.

## Orchestration (load first)

**[htb-workflow](htb-workflow/SKILL.md)** is the conductor: it maps each phase to
the **MITRE ATT&CK** tactics, decides which skill to call next, and defines the
format of the shared state files (`creds.txt`, `notes.md`). The agent loads it at
the start of the box, then delegates to the specialized skills below. At the end
of the box, it generates an **ATT&CK Navigator report** (importable JSON layer)
via `htb-workflow/gen-navigator-layer.py`.

## Logical order of an HTB engagement

```
                         ┌──────────────┐
                         │ htb-workflow │  (orchestrator, MITRE ATT&CK)
                         └──────┬───────┘
                                ▼
htb-preflight ──► htb-recon ──► htb-web-enum ─┐
(scope+VPN)                 └─► htb-smb-enum ─┼─► htb-exploitation ──► htb-shells ──► htb-privesc
                            └─► htb-active-directory ┘                                     │
                                                                                           ▼
                               htb-password-attacks (cross-cutting)    htb-pivoting ──► htb-report
                                                                    (multi-host)   (report + ATT&CK layer)
```

## Skill index

| Skill | Trigger | Role |
|---|---|---|
| [htb-workflow](htb-workflow/SKILL.md) | Start of box / "what next?" | MITRE ATT&CK-aligned orchestrator, shared state |
| [htb-preflight](htb-preflight/SKILL.md) | Before any action | Scope + VPN check (tun0), sets IP/LHOST |
| [htb-recon](htb-recon/SKILL.md) | Target IP, start of box | Port/service scan (nmap, rustscan, masscan) |
| [htb-web-enum](htb-web-enum/SKILL.md) | Port 80/443/8080 open | Fuzzing, vhosts, CMS (ffuf, feroxbuster, wpscan) |
| [htb-smb-enum](htb-smb-enum/SKILL.md) | Port 445/139/389 | Shares, users, null session (netexec, enum4linux-ng) |
| [htb-active-directory](htb-active-directory/SKILL.md) | Domain Controller / .htb domain | Kerberoast, BloodHound, PtH, DCSync |
| [htb-password-attacks](htb-password-attacks/SKILL.md) | Hash or auth service | Cracking & brute force (hashcat, john, hydra) |
| [htb-exploitation](htb-exploitation/SKILL.md) | Known service + version | Public exploit / Metasploit → foothold |
| [htb-shells](htb-shells/SKILL.md) | RCE / injection obtained | Reverse shell + TTY stabilization |
| [htb-privesc](htb-privesc/SKILL.md) | Unprivileged shell | Escalation to root/SYSTEM (linpeas, GTFOBins) |
| [htb-pivoting](htb-pivoting/SKILL.md) | Internal network unreachable | Tunnels (ligolo-ng, chisel, proxychains) |
| [htb-report](htb-report/SKILL.md) | Flags obtained, end of box | Markdown -> PDF report + ATT&CK Navigator appendix |

## Conventions

- `LHOST` / attack IP = the HTB VPN interface (`tun0`), never `eth0`.
- Every credential found goes into a `creds.txt` and is replayed everywhere (reuse).
- Tool outputs are saved (`-oN`, `-o`) for re-parsing by the agent.

## Legal framework

These skills describe offensive techniques intended **exclusively** for
authorized targets: assigned Hack The Box machines, personal labs, CTFs, and
systems you own or have written permission to test. Any use outside this
framework is forbidden.

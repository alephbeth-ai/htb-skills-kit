---
name: htb-workflow
description: >
  Orchestrator for Hack The Box / authorized-lab engagements, aligned with the
  MITRE ATT&CK framework. Trigger it at the very start of a box, or whenever the
  agent must decide "what to do next". This skill is the conductor: it maps each
  phase (Recon → Initial Access → Execution → PrivEsc → Lateral Movement →
  Collection) onto ATT&CK tactics and onto the specialized htb-* skills, defines
  the shared format of creds.txt / notes, and sets the criteria for moving from
  one phase to the next. Produces an ordered attack plan and the current state.
metadata:
  type: reference
  category: orchestration
  framework: "MITRE ATT&CK Enterprise"
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Engagement orchestration (MITRE ATT&CK-aligned)

## Role of this skill
This is the **entry point** and the **supervisor**. The agent loads it first,
then delegates each step to a specialized skill (`htb-recon`, `htb-web-enum`…).
It continuously answers three questions:
1. Where am I? (state, current ATT&CK tactic)
2. Which skill do I call now?
3. What criterion moves me to the next phase?

## Guardrail
Only orchestrate against authorized targets (assigned HTB IP, lab, CTF, system
you own). Log every action. Never expand the scope.

---

## Orchestration loop (state machine)

```
        ┌──────────────────────────────────────────────────────────────┐
        │  For EACH target/host:                                       │
        │  1. Ask yourself: what is the current ATT&CK tactic?         │
        │  2. Call the matching htb-* skill                            │
        │  3. Record findings in notes.md / creds.txt                  │
        │  4. Replay every new credential EVERYWHERE (password reuse)  │
        │  5. Exit criterion met? -> next phase, otherwise 1           │
        └──────────────────────────────────────────────────────────────┘
```

Guiding principle: **enumerate before exploiting**, **replay creds everywhere**,
**log everything**.

---

## Phases mapped onto MITRE ATT&CK

| # | HTB phase | ATT&CK tactic (ID) | Key techniques (ID) | Delegated skill | Exit criterion |
|---|---|---|---|---|---|
| 0 | Preflight (outside ATT&CK) | — | Scope check + VPN (tun0), scaffolding | `htb-preflight` | Green light: IP/LHOST set, folder created |
| 1 | Network reconnaissance | Reconnaissance (TA0043), Discovery (TA0007) | Active Scanning (T1595), Network Service Discovery (T1046) | `htb-recon` | Ports/services list established |
| 2 | Service enumeration | Reconnaissance (TA0043) | Gather Victim Host Info (T1592), Vuln Scanning (T1595.002) | `htb-web-enum`, `htb-smb-enum`, `htb-active-directory` | Entry vector or creds identified |
| 3 | Credential access | Credential Access (TA0006) | Brute Force (T1110), Kerberoasting (T1558.003), AS-REP Roasting (T1558.004) | `htb-password-attacks`, `htb-active-directory` | At least one valid credential |
| 4 | Initial access | Initial Access (TA0001) | Exploit Public-Facing App (T1190), Valid Accounts (T1078) | `htb-exploitation`, `htb-smb-enum` | Code execution / session obtained |
| 5 | Execution & foothold | Execution (TA0002) | Command/Scripting Interpreter (T1059) | `htb-shells` | Stable interactive shell (user flag) |
| 6 | Privilege escalation | Privilege Escalation (TA0004) | Abuse Elevation Control (T1548), Exploitation for PrivEsc (T1068) | `htb-privesc`, `htb-active-directory` | root / SYSTEM / Domain Admin |
| 7 | Persistence (optional on HTB) | Persistence (TA0003) | Valid Accounts (T1078), SSH Authorized Keys (T1098.004) | `htb-privesc` | Reproducible access (if useful) |
| 8 | Lateral movement | Lateral Movement (TA0008) | Pass-the-Hash (T1550.002), Remote Services (T1021) | `htb-active-directory`, `htb-shells` | New host compromised |
| 9 | Network pivoting | Lateral Movement (TA0008), Command & Control (TA0011) | Internal Proxy (T1090.001), Protocol Tunneling (T1572) | `htb-pivoting` | Internal network routable |
| 10 | Flag collection & reporting | Collection (TA0009) | Data from Local System (T1005) | `htb-report` (+ ATT&CK layer) | user.txt + root.txt + report produced |

> HTB note: Persistence (phase 7) and real exfiltration are rarely needed on a
> simple box; they are relevant in multi-host Pro Labs.

---

## Decision tree "what to do next?"

```
Scope/VPN not checked yet?              -> htb-preflight  (+ ./bin/new-box.sh)
Nothing done yet?                       -> htb-recon                     (T1046)
Port 80/443/8080 open?                  -> htb-web-enum                  (T1595.002)
Port 445/139/389 open?                  -> htb-smb-enum                  (T1592)
Domain Controller / .htb domain?        -> htb-active-directory          (TA0006/TA0008)
Got a hash / a login to crack?          -> htb-password-attacks          (T1110/T1558)
Got service+version, no access?         -> htb-exploitation              (T1190)
Got an RCE / injection?                 -> htb-shells                    (T1059)
Got an unprivileged shell?              -> htb-privesc                   (T1548/T1068)
New creds found?                        -> replay them EVERYWHERE, then loop back
2nd interface / internal network?       -> htb-pivoting                  (T1090/T1572)
user.txt + root.txt?                    -> htb-report (report + ATT&CK layer)
```

Cross-cutting rule: **for every new credential**, go back through phase 4
(Valid Accounts, T1078) against all known services before continuing.

---

## Shared state files (contract between skills)

The agent maintains one engagement folder per target. Every skill reads and
writes these files.

### `creds.txt` — format
One line per credential, fields separated by `|`:
```
# host | service | domain | user | secret | type | source | validated(y/n)
10.10.10.10 | smb    | MACHINE | svc_web | Summer2024! | password | Backup share | y
10.10.10.10 | ntlm   | MACHINE | admin   | aad3b...:e19cc... | hash     | secretsdump   | y
10.10.10.10 | ssh    | -       | john    | -               | key      | /home/john/.ssh | y
```
- `type` ∈ `password | hash | ntlm | key | ticket`
- Any credential with `validated=y` must be tested against SMB / WinRM / SSH / MSSQL / LDAP.

### `notes.md` — skeleton
```markdown
# <Box name> — <IP>
## Current ATT&CK state: <tactic / phase #>

## Ports & services (htb-recon)
- 22/tcp ssh OpenSSH 8.2
- 80/tcp http nginx 1.18

## Web surface (htb-web-enum)
## SMB / AD (htb-smb-enum / htb-active-directory)
## Foothold (how obtained, T####)
## PrivEsc (vector, T####)
## Internal hosts (htb-pivoting)
## Flags
- user.txt: ...
- root.txt: ...
```

### `hosts.md` (multi-machine labs)
Table: `host | role | interfaces/networks seen | access obtained | pivots to`.

---

## Final report — ATT&CK Navigator

At the end of a box (user.txt + root.txt obtained), the agent produces an
**ATT&CK Navigator layer** visualizing every technique used. Two files are
provided:

- `gen-navigator-layer.py` — generator (catalog of the htb-* skills' techniques).
- `techniques.example.txt` — sample input (one `ID[:comment]` per line).
- `attack-navigator-layer.template.json` — pre-generated template layer, importable as-is.

### Procedure
1. Throughout the box, add each technique used to a `techniques.txt` (in the
   `T####[:comment]` format), or derive it from `notes.md`.
2. Generate the layer:
   ```bash
   python3 gen-navigator-layer.py -n "Box name" -f techniques.txt -o box.json
   # or by passing the IDs directly:
   python3 gen-navigator-layer.py -n "Forest" T1046 T1558.004:AS-REP T1550.002:PtH -o forest.json
   ```
3. Import into <https://mitre-attack.github.io/attack-navigator/>:
   **Open Existing Layer → Upload from local → box.json**.
   The techniques used show up in red (score 100), with the comment on hover.

### Integration into the loop
Phase 10 (Collection, TA0009) ends with the generation of this layer. The agent
populates `techniques.txt` alongside `creds.txt`/`notes.md`: each call to an
htb-* skill corresponds to one or more techniques from the ATT&CK table above,
which it records the moment they succeed.

## Expected agent output on each turn
When this skill is active, the agent responds in a structured way:
1. **Current ATT&CK phase** (name + ID).
2. **Finding**: what the previous step produced.
3. **Next action**: which htb-* skill and why.
4. **State update**: lines added to `creds.txt` / `notes.md`.

## Attack conventions
- `LHOST` = HTB VPN interface (`tun0`), never `eth0` — check `ip a show tun0`.
- Save every tool's output (`-oN`, `-o`) for re-parsing.
- Prefer full enumeration over early exploitation.
- Do not run an unreviewed exploit (see `htb-exploitation`).

## ATT&CK references
MITRE ATT&CK Enterprise framework. The identifiers (T####, TA####) let the agent
trace every action and produce an ATT&CK-aligned report at the end of the
engagement.

---
name: htb-workflow
description: >
  Orchestrateur d'engagement Hack The Box / lab autorisé, aligné sur le framework
  MITRE ATT&CK. À déclencher au tout début d'une box, ou quand l'agent doit
  décider "quoi faire ensuite". Cette skill est le chef d'orchestre : elle mappe
  chaque phase (Recon → Initial Access → Execution → PrivEsc → Lateral Movement →
  Collection) sur les tactiques ATT&CK et sur les skills htb-* spécialisées,
  définit le format partagé de creds.txt / notes, et fixe les critères de passage
  d'une phase à la suivante. Produit un plan d'attaque ordonné et l'état courant.
metadata:
  type: reference
  category: orchestration
  framework: "MITRE ATT&CK Enterprise"
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Orchestration d'engagement (aligné MITRE ATT&CK)

## Rôle de cette skill
C'est le **point d'entrée** et le **superviseur**. L'agent la charge en premier,
puis délègue chaque étape à une skill spécialisée (`htb-recon`, `htb-web-enum`…).
Elle répond en continu à trois questions :
1. Où en suis-je ? (état, tactique ATT&CK courante)
2. Quelle skill appeler maintenant ?
3. Quel critère me fait passer à la phase suivante ?

## Garde-fou
N'orchestrer que contre des cibles autorisées (IP HTB assignée, lab, CTF, système
possédé). Journaliser chaque action. Ne jamais élargir le périmètre.

---

## Boucle d'orchestration (machine à états)

```
        ┌──────────────────────────────────────────────────────────────┐
        │  Pour CHAQUE cible/host :                                     │
        │  1. Se demander : quelle est la tactique ATT&CK en cours ?    │
        │  2. Appeler la skill htb-* correspondante                     │
        │  3. Enregistrer les trouvailles dans notes.md / creds.txt     │
        │  4. Rejouer tout nouveau credential PARTOUT (password reuse)   │
        │  5. Critère de sortie atteint ? -> phase suivante, sinon 1    │
        └──────────────────────────────────────────────────────────────┘
```

Principe directeur : **énumérer avant d'exploiter**, **rejouer les creds partout**,
**tout consigner**.

---

## Phases mappées sur MITRE ATT&CK

| # | Phase HTB | Tactique ATT&CK (ID) | Techniques clés (ID) | Skill déléguée | Critère de sortie |
|---|---|---|---|---|---|
| 0 | Preflight (hors ATT&CK) | — | Contrôle périmètre + VPN (tun0), scaffolding | `htb-preflight` | Feu vert : IP/LHOST fixés, dossier créé |
| 1 | Reconnaissance réseau | Reconnaissance (TA0043), Discovery (TA0007) | Active Scanning (T1595), Network Service Discovery (T1046) | `htb-recon` | Liste des ports/services établie |
| 2 | Énumération des services | Reconnaissance (TA0043) | Gather Victim Host Info (T1592), Vuln Scanning (T1595.002) | `htb-web-enum`, `htb-smb-enum`, `htb-active-directory` | Vecteur d'entrée ou creds identifiés |
| 3 | Accès aux identifiants | Credential Access (TA0006) | Brute Force (T1110), Kerberoasting (T1558.003), AS-REP Roasting (T1558.004) | `htb-password-attacks`, `htb-active-directory` | Au moins un credential valide |
| 4 | Accès initial | Initial Access (TA0001) | Exploit Public-Facing App (T1190), Valid Accounts (T1078) | `htb-exploitation`, `htb-smb-enum` | Exécution de code / session obtenue |
| 5 | Exécution & foothold | Execution (TA0002) | Command/Scripting Interpreter (T1059) | `htb-shells` | Shell interactif stable (user flag) |
| 6 | Élévation de privilèges | Privilege Escalation (TA0004) | Abuse Elevation Control (T1548), Exploitation for PrivEsc (T1068) | `htb-privesc`, `htb-active-directory` | root / SYSTEM / Domain Admin |
| 7 | Persistance (optionnel HTB) | Persistence (TA0003) | Valid Accounts (T1078), SSH Authorized Keys (T1098.004) | `htb-privesc` | Accès reproductible (si utile) |
| 8 | Mouvement latéral | Lateral Movement (TA0008) | Pass-the-Hash (T1550.002), Remote Services (T1021) | `htb-active-directory`, `htb-shells` | Nouveau host compromis |
| 9 | Pivoting réseau | Lateral Movement (TA0008), Command & Control (TA0011) | Internal Proxy (T1090.001), Protocol Tunneling (T1572) | `htb-pivoting` | Réseau interne routable |
| 10 | Collecte flags & rapport | Collection (TA0009) | Data from Local System (T1005) | `htb-report` (+ layer ATT&CK) | user.txt + root.txt + rapport produit |

> Note HTB : la Persistance (phase 7) et l'exfiltration réelle sont rarement
> nécessaires sur une box simple ; elles sont pertinentes en Pro Lab multi-hôtes.

---

## Arbre de décision "quoi faire ensuite ?"

```
Pas encore vérifié périmètre/VPN ?    -> htb-preflight  (+ ./bin/new-box.sh)
Rien encore ?                         -> htb-recon                     (T1046)
Port 80/443/8080 ouvert ?             -> htb-web-enum                  (T1595.002)
Port 445/139/389 ouvert ?             -> htb-smb-enum                  (T1592)
Domain Controller / domaine .htb ?    -> htb-active-directory          (TA0006/TA0008)
J'ai un hash / un login à forcer ?    -> htb-password-attacks          (T1110/T1558)
J'ai service+version, pas d'accès ?   -> htb-exploitation              (T1190)
J'ai une RCE / injection ?            -> htb-shells                    (T1059)
J'ai un shell non privilégié ?        -> htb-privesc                   (T1548/T1068)
Nouveaux creds trouvés ?              -> les rejouer PARTOUT, puis reboucler
2e interface / réseau interne ?       -> htb-pivoting                  (T1090/T1572)
user.txt + root.txt ?                 -> htb-report (rapport + ATT&CK layer)
```

Règle transverse : **à chaque nouveau credential**, repasser par la phase 4
(Valid Accounts, T1078) sur tous les services connus avant de continuer.

---

## Fichiers d'état partagés (contrat entre skills)

L'agent maintient un dossier d'engagement par cible. Toutes les skills lisent et
écrivent ces fichiers.

### `creds.txt` — format
Une ligne par identifiant, champs séparés par `|` :
```
# host | service | domaine | user | secret | type | source | validé(o/n)
10.10.10.10 | smb    | MACHINE | svc_web | Summer2024! | password | partage Backup | o
10.10.10.10 | ntlm   | MACHINE | admin   | aad3b...:e19cc... | hash     | secretsdump   | o
10.10.10.10 | ssh    | -       | john    | -               | key      | /home/john/.ssh | o
```
- `type` ∈ `password | hash | ntlm | key | ticket`
- Tout credential `validé=o` doit être testé sur SMB / WinRM / SSH / MSSQL / LDAP.

### `notes.md` — squelette
```markdown
# <Nom box> — <IP>
## État ATT&CK courant : <tactique / phase #>

## Ports & services (htb-recon)
- 22/tcp ssh OpenSSH 8.2
- 80/tcp http nginx 1.18

## Surface web (htb-web-enum)
## SMB / AD (htb-smb-enum / htb-active-directory)
## Foothold (comment obtenu, T####)
## PrivEsc (vecteur, T####)
## Hosts internes (htb-pivoting)
## Flags
- user.txt : ...
- root.txt : ...
```

### `hosts.md` (labs multi-machines)
Table : `host | rôle | interfaces/réseaux vus | accès obtenu | pivote vers`.

---

## Rapport final — ATT&CK Navigator

En fin de box (user.txt + root.txt obtenus), l'agent produit un **layer ATT&CK
Navigator** visualisant toutes les techniques employées. Deux fichiers fournis :

- `gen-navigator-layer.py` — générateur (catalogue des techniques des skills htb-*).
- `techniques.example.txt` — exemple d'entrée (un `ID[:commentaire]` par ligne).
- `attack-navigator-layer.template.json` — layer modèle déjà généré, importable tel quel.

### Procédure
1. Tout au long de la box, ajouter chaque technique employée dans un
   `techniques.txt` (au format `T####[:commentaire]`), ou la déduire de `notes.md`.
2. Générer le layer :
   ```bash
   python3 gen-navigator-layer.py -n "Nom de la box" -f techniques.txt -o box.json
   # ou en passant les IDs directement :
   python3 gen-navigator-layer.py -n "Forest" T1046 T1558.004:AS-REP T1550.002:PtH -o forest.json
   ```
3. Importer dans <https://mitre-attack.github.io/attack-navigator/> :
   **Open Existing Layer → Upload from local → box.json**.
   Les techniques employées ressortent en rouge (score 100), le commentaire au survol.

### Intégration dans la boucle
La phase 10 (Collection, TA0009) se termine par la génération de ce layer. L'agent
alimente `techniques.txt` en parallèle de `creds.txt`/`notes.md` : chaque appel à
une skill htb-* correspond à une ou plusieurs techniques du tableau ATT&CK ci-dessus,
qu'il consigne au moment où elles réussissent.

## Sortie attendue de l'agent à chaque tour
Quand cette skill est active, l'agent répond de façon structurée :
1. **Phase ATT&CK courante** (nom + ID).
2. **Constat** : ce que l'étape précédente a produit.
3. **Prochaine action** : quelle skill htb-* et pourquoi.
4. **Mise à jour d'état** : lignes ajoutées à `creds.txt` / `notes.md`.

## Convention d'attaque
- `LHOST` = interface VPN HTB (`tun0`), jamais `eth0` — vérifier `ip a show tun0`.
- Sauvegarder chaque sortie d'outil (`-oN`, `-o`) pour re-parsing.
- Préférer l'énumération complète à l'exploitation précoce.
- Ne pas exécuter d'exploit non relu (cf. `htb-exploitation`).

## Références ATT&CK
Framework MITRE ATT&CK Enterprise. Les identifiants (T####, TA####) permettent
à l'agent de tracer chaque action et de produire un rapport aligné sur ATT&CK en
fin d'engagement.

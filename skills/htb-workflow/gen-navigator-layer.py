#!/usr/bin/env python3
# ==============================================================================
# gen-navigator-layer.py — Génère un layer MITRE ATT&CK Navigator en fin de box
# ------------------------------------------------------------------------------
# En fin d'engagement HTB/lab autorisé, produit un fichier JSON importable dans
# https://mitre-attack.github.io/attack-navigator/ pour visualiser les techniques
# employées pendant la box.
#
# Usage :
#   # via une liste d'IDs (argv), commentaire optionnel après ':'
#   python3 gen-navigator-layer.py -n "Box Forest" T1046 T1595.002 \
#       "T1558.004:AS-REP roast de svc-alfresco" T1550.002:PtH -o forest.json
#
#   # ou depuis un fichier techniques.txt (un ID[:commentaire] par ligne)
#   python3 gen-navigator-layer.py -n "Box Forest" -f techniques.txt -o forest.json
#
# Le fichier techniques.txt accepte les commentaires '#' et lignes vides.
# ==============================================================================
import argparse, datetime, json, sys

# Catalogue des techniques couvertes par les skills htb-* (nom + tactique).
# Toute technique fournie mais absente du catalogue est tout de même ajoutée
# au layer (name "?"), pour ne jamais perdre une observation.
CATALOG = {
    "T1595":     ("Active Scanning",                        "reconnaissance"),
    "T1595.002": ("Active Scanning: Vulnerability Scanning", "reconnaissance"),
    "T1592":     ("Gather Victim Host Information",          "reconnaissance"),
    "T1046":     ("Network Service Discovery",              "discovery"),
    "T1087":     ("Account Discovery",                       "discovery"),
    "T1110":     ("Brute Force",                             "credential-access"),
    "T1110.003": ("Brute Force: Password Spraying",          "credential-access"),
    "T1558.003": ("Steal/Forge Kerberos Tickets: Kerberoasting", "credential-access"),
    "T1558.004": ("Steal/Forge Kerberos Tickets: AS-REP Roasting", "credential-access"),
    "T1003":     ("OS Credential Dumping",                   "credential-access"),
    "T1003.006": ("OS Credential Dumping: DCSync",           "credential-access"),
    "T1552":     ("Unsecured Credentials",                   "credential-access"),
    "T1190":     ("Exploit Public-Facing Application",       "initial-access"),
    "T1078":     ("Valid Accounts",                          "initial-access"),
    "T1133":     ("External Remote Services",                "initial-access"),
    "T1059":     ("Command and Scripting Interpreter",       "execution"),
    "T1203":     ("Exploitation for Client Execution",       "execution"),
    "T1548":     ("Abuse Elevation Control Mechanism",       "privilege-escalation"),
    "T1068":     ("Exploitation for Privilege Escalation",   "privilege-escalation"),
    "T1134":     ("Access Token Manipulation",               "privilege-escalation"),
    "T1098.004": ("Account Manipulation: SSH Authorized Keys", "persistence"),
    "T1053":     ("Scheduled Task/Job",                      "persistence"),
    "T1550.002": ("Use Alternate Auth Material: Pass the Hash", "lateral-movement"),
    "T1021":     ("Remote Services",                         "lateral-movement"),
    "T1021.006": ("Remote Services: Windows Remote Management", "lateral-movement"),
    "T1090":     ("Proxy",                                   "command-and-control"),
    "T1090.001": ("Proxy: Internal Proxy",                   "command-and-control"),
    "T1572":     ("Protocol Tunneling",                      "command-and-control"),
    "T1005":     ("Data from Local System",                  "collection"),
}

USED_SCORE = 100
USED_COLOR = "#c0392b"  # rouge : technique employée


def load_from_file(path):
    items = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            items.append(line)
    return items


def parse_item(raw):
    """'T1558.004:commentaire' -> (id, commentaire)."""
    if ":" in raw:
        tid, comment = raw.split(":", 1)
        return tid.strip(), comment.strip()
    return raw.strip(), ""


def build_layer(name, items, description):
    techniques, unknown = [], []
    seen = set()
    for raw in items:
        tid, comment = parse_item(raw)
        if not tid:
            continue
        if tid in seen:
            continue
        seen.add(tid)
        if tid not in CATALOG:
            unknown.append(tid)
        techniques.append({
            "techniqueID": tid,
            "score": USED_SCORE,
            "color": USED_COLOR,
            "comment": comment,
            "enabled": True,
            "metadata": [],
            "links": [],
            "showSubtechniques": bool("." in tid),
        })
    layer = {
        "name": name,
        "versions": {"attack": "15", "navigator": "4.9.0", "layer": "4.5"},
        "domain": "enterprise-attack",
        "description": description,
        "filters": {"platforms": ["Linux", "Windows", "Network"]},
        "sorting": 0,
        "layout": {"layout": "side", "showID": True, "showName": True},
        "hideDisabled": False,
        "techniques": techniques,
        "gradient": {
            "colors": ["#ffffff", "#c0392b"],
            "minValue": 0,
            "maxValue": 100,
        },
        "legendItems": [
            {"label": "Technique employée sur la box", "color": USED_COLOR}
        ],
        "metadata": [
            {"name": "généré", "value": datetime.date.today().isoformat()},
            {"name": "outil", "value": "htb-workflow/gen-navigator-layer.py"},
        ],
        "showTacticRowBackground": True,
        "tacticRowBackground": "#205b70",
        "selectTechniquesAcrossTactics": True,
        "selectSubtechniquesWithParent": False,
    }
    return layer, unknown


def main():
    p = argparse.ArgumentParser(description="Génère un layer ATT&CK Navigator (fin de box HTB).")
    p.add_argument("-n", "--name", required=True, help="Nom du layer (ex. nom de la box).")
    p.add_argument("-f", "--file", help="Fichier techniques.txt (un ID[:commentaire] par ligne).")
    p.add_argument("-o", "--output", default="attack-layer.json", help="Fichier de sortie JSON.")
    p.add_argument("-d", "--description", default="", help="Description libre du layer.")
    p.add_argument("ids", nargs="*", help="IDs de techniques (ex. T1046 T1558.004:comment).")
    args = p.parse_args()

    items = list(args.ids)
    if args.file:
        items += load_from_file(args.file)
    if not items:
        p.error("Fournir des techniques via des arguments ou -f fichier.")

    desc = args.description or f"Techniques MITRE ATT&CK employées — {args.name} (HTB, cible autorisée)."
    layer, unknown = build_layer(args.name, items, desc)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(layer, fh, indent=2, ensure_ascii=False)

    print(f"[+] Layer écrit : {args.output}  ({len(layer['techniques'])} techniques)")
    if unknown:
        print(f"[!] Hors catalogue (ajoutées quand même) : {', '.join(unknown)}", file=sys.stderr)
    print("[*] Importer dans https://mitre-attack.github.io/attack-navigator/ "
          "-> Open Existing Layer -> Upload from local.")


if __name__ == "__main__":
    main()

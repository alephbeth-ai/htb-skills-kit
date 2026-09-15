#!/usr/bin/env python3
# ==============================================================================
# gen-navigator-layer.py — Generates a MITRE ATT&CK Navigator layer at box end
# ------------------------------------------------------------------------------
# At the end of an HTB/authorized-lab engagement, produces a JSON file importable
# into https://mitre-attack.github.io/attack-navigator/ to visualize the
# techniques used during the box.
#
# Usage:
#   # via a list of IDs (argv), optional comment after ':'
#   python3 gen-navigator-layer.py -n "Box Forest" T1046 T1595.002 \
#       "T1558.004:AS-REP roast of svc-alfresco" T1550.002:PtH -o forest.json
#
#   # or from a techniques.txt file (one ID[:comment] per line)
#   python3 gen-navigator-layer.py -n "Box Forest" -f techniques.txt -o forest.json
#
# The techniques.txt file accepts '#' comments and blank lines.
# ==============================================================================
import argparse, datetime, json, sys

# Catalog of techniques covered by the htb-* skills (name + tactic).
# Any technique provided but missing from the catalog is still added to the
# layer (name "?"), so an observation is never lost.
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
USED_COLOR = "#c0392b"  # red: technique used


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
    """'T1558.004:comment' -> (id, comment)."""
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
            {"label": "Technique used on the box", "color": USED_COLOR}
        ],
        "metadata": [
            {"name": "generated", "value": datetime.date.today().isoformat()},
            {"name": "tool", "value": "htb-workflow/gen-navigator-layer.py"},
        ],
        "showTacticRowBackground": True,
        "tacticRowBackground": "#205b70",
        "selectTechniquesAcrossTactics": True,
        "selectSubtechniquesWithParent": False,
    }
    return layer, unknown


def main():
    p = argparse.ArgumentParser(description="Generates an ATT&CK Navigator layer (end of HTB box).")
    p.add_argument("-n", "--name", required=True, help="Layer name (e.g. box name).")
    p.add_argument("-f", "--file", help="techniques.txt file (one ID[:comment] per line).")
    p.add_argument("-o", "--output", default="attack-layer.json", help="JSON output file.")
    p.add_argument("-d", "--description", default="", help="Free-form layer description.")
    p.add_argument("ids", nargs="*", help="Technique IDs (e.g. T1046 T1558.004:comment).")
    args = p.parse_args()

    items = list(args.ids)
    if args.file:
        items += load_from_file(args.file)
    if not items:
        p.error("Provide techniques via arguments or -f file.")

    desc = args.description or f"MITRE ATT&CK techniques used — {args.name} (HTB, authorized target)."
    layer, unknown = build_layer(args.name, items, desc)

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(layer, fh, indent=2, ensure_ascii=False)

    print(f"[+] Layer written: {args.output}  ({len(layer['techniques'])} techniques)")
    if unknown:
        print(f"[!] Off-catalog (added anyway): {', '.join(unknown)}", file=sys.stderr)
    print("[*] Import into https://mitre-attack.github.io/attack-navigator/ "
          "-> Open Existing Layer -> Upload from local.")


if __name__ == "__main__":
    main()

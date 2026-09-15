#!/usr/bin/env python3
# ==============================================================================
# validate.py — Contrôles de cohérence du dépôt (utilisé par la CI)
# ------------------------------------------------------------------------------
# 1. Chaque skills/<nom>/SKILL.md a un frontmatter YAML valide avec 'name' et
#    'description', et 'name' correspond au nom du dossier.
# 2. Le layer ATT&CK Navigator (JSON) est valide et bien formé.
# 3. gen-navigator-layer.py s'exécute et produit un JSON valide.
#
# Sortie : code 0 si tout est bon, 1 sinon, avec la liste des erreurs.
# Usage : python tools/validate.py [racine_du_depot]
# ==============================================================================
import json
import pathlib
import re
import subprocess
import sys
import tempfile

import yaml

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
errors: list[str] = []
checks = 0


def fail(msg: str) -> None:
    errors.append(msg)


def parse_frontmatter(text: str):
    """Extrait le bloc YAML entre les deux '---' de tête."""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None
    return yaml.safe_load(m.group(1))


def validate_skills() -> None:
    global checks
    skills_dir = ROOT / "skills"
    skill_files = sorted(skills_dir.glob("*/SKILL.md"))
    if not skill_files:
        fail("Aucun SKILL.md trouvé sous skills/")
        return
    names = set()
    for sf in skill_files:
        checks += 1
        rel = sf.relative_to(ROOT)
        text = sf.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)
        if fm is None:
            fail(f"{rel}: frontmatter YAML absent ou mal formé")
            continue
        if not isinstance(fm, dict):
            fail(f"{rel}: le frontmatter n'est pas un mapping YAML")
            continue
        name = fm.get("name")
        desc = fm.get("description")
        if not name:
            fail(f"{rel}: champ 'name' manquant")
        if not desc:
            fail(f"{rel}: champ 'description' manquant")
        dir_name = sf.parent.name
        if name and name != dir_name:
            fail(f"{rel}: name='{name}' != dossier '{dir_name}'")
        if name in names:
            fail(f"{rel}: nom de skill dupliqué '{name}'")
        names.add(name)
    print(f"[skills] {len(skill_files)} SKILL.md vérifiés")


def validate_layer_json() -> None:
    global checks
    layer = ROOT / "skills/htb-workflow/attack-navigator-layer.template.json"
    if not layer.exists():
        fail(f"{layer.relative_to(ROOT)}: fichier absent")
        return
    checks += 1
    try:
        data = json.loads(layer.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        fail(f"{layer.relative_to(ROOT)}: JSON invalide ({e})")
        return
    for key in ("name", "versions", "domain", "techniques"):
        if key not in data:
            fail(f"{layer.relative_to(ROOT)}: clé '{key}' manquante")
    if not isinstance(data.get("techniques"), list) or not data["techniques"]:
        fail(f"{layer.relative_to(ROOT)}: 'techniques' doit être une liste non vide")
    for t in data.get("techniques", []):
        if "techniqueID" not in t:
            fail(f"{layer.relative_to(ROOT)}: une technique sans 'techniqueID'")
            break
    print(f"[layer] {len(data.get('techniques', []))} techniques, JSON valide")


def validate_generator() -> None:
    global checks
    gen = ROOT / "skills/htb-workflow/gen-navigator-layer.py"
    ex = ROOT / "skills/htb-workflow/techniques.example.txt"
    if not gen.exists() or not ex.exists():
        fail("gen-navigator-layer.py ou techniques.example.txt absent")
        return
    checks += 1
    with tempfile.TemporaryDirectory() as td:
        out = pathlib.Path(td) / "out.json"
        r = subprocess.run(
            [sys.executable, str(gen), "-n", "CI-Test", "-f", str(ex), "-o", str(out)],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            fail(f"gen-navigator-layer.py a échoué : {r.stderr.strip()}")
            return
        try:
            data = json.loads(out.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, FileNotFoundError) as e:
            fail(f"gen-navigator-layer.py : sortie JSON invalide ({e})")
            return
        if not data.get("techniques"):
            fail("gen-navigator-layer.py : layer sans techniques")
    print(f"[generator] exécution OK, {len(data.get('techniques', []))} techniques générées")


def main() -> int:
    print(f"== Validation du dépôt : {ROOT} ==")
    validate_skills()
    validate_layer_json()
    validate_generator()
    print(f"\n{checks} groupes de contrôles exécutés.")
    if errors:
        print(f"\n[ECHEC] {len(errors)} erreur(s) :")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("\n[OK] Tout est valide.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

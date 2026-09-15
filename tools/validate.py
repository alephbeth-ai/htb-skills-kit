#!/usr/bin/env python3
# ==============================================================================
# validate.py — Repository consistency checks (used by CI)
# ------------------------------------------------------------------------------
# 1. Each skills/<name>/SKILL.md has valid YAML frontmatter with 'name' and
#    'description', and 'name' matches the folder name.
# 2. The ATT&CK Navigator layer (JSON) is valid and well-formed.
# 3. gen-navigator-layer.py runs and produces valid JSON.
#
# Output: exit code 0 if everything is fine, 1 otherwise, with the list of errors.
# Usage: python tools/validate.py [repo_root]
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
    """Extract the YAML block between the two leading '---'."""
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if not m:
        return None
    return yaml.safe_load(m.group(1))


def validate_skills() -> None:
    global checks
    skills_dir = ROOT / "skills"
    skill_files = sorted(skills_dir.glob("*/SKILL.md"))
    if not skill_files:
        fail("No SKILL.md found under skills/")
        return
    names = set()
    for sf in skill_files:
        checks += 1
        rel = sf.relative_to(ROOT)
        text = sf.read_text(encoding="utf-8")
        fm = parse_frontmatter(text)
        if fm is None:
            fail(f"{rel}: YAML frontmatter missing or malformed")
            continue
        if not isinstance(fm, dict):
            fail(f"{rel}: the frontmatter is not a YAML mapping")
            continue
        name = fm.get("name")
        desc = fm.get("description")
        if not name:
            fail(f"{rel}: 'name' field missing")
        if not desc:
            fail(f"{rel}: 'description' field missing")
        dir_name = sf.parent.name
        if name and name != dir_name:
            fail(f"{rel}: name='{name}' != folder '{dir_name}'")
        if name in names:
            fail(f"{rel}: duplicate skill name '{name}'")
        names.add(name)
    print(f"[skills] {len(skill_files)} SKILL.md checked")


def validate_layer_json() -> None:
    global checks
    layer = ROOT / "skills/htb-workflow/attack-navigator-layer.template.json"
    if not layer.exists():
        fail(f"{layer.relative_to(ROOT)}: file missing")
        return
    checks += 1
    try:
        data = json.loads(layer.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        fail(f"{layer.relative_to(ROOT)}: invalid JSON ({e})")
        return
    for key in ("name", "versions", "domain", "techniques"):
        if key not in data:
            fail(f"{layer.relative_to(ROOT)}: key '{key}' missing")
    if not isinstance(data.get("techniques"), list) or not data["techniques"]:
        fail(f"{layer.relative_to(ROOT)}: 'techniques' must be a non-empty list")
    for t in data.get("techniques", []):
        if "techniqueID" not in t:
            fail(f"{layer.relative_to(ROOT)}: a technique without 'techniqueID'")
            break
    print(f"[layer] {len(data.get('techniques', []))} techniques, valid JSON")


def validate_generator() -> None:
    global checks
    gen = ROOT / "skills/htb-workflow/gen-navigator-layer.py"
    ex = ROOT / "skills/htb-workflow/techniques.example.txt"
    if not gen.exists() or not ex.exists():
        fail("gen-navigator-layer.py or techniques.example.txt missing")
        return
    checks += 1
    with tempfile.TemporaryDirectory() as td:
        out = pathlib.Path(td) / "out.json"
        r = subprocess.run(
            [sys.executable, str(gen), "-n", "CI-Test", "-f", str(ex), "-o", str(out)],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            fail(f"gen-navigator-layer.py failed: {r.stderr.strip()}")
            return
        try:
            data = json.loads(out.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, FileNotFoundError) as e:
            fail(f"gen-navigator-layer.py: invalid JSON output ({e})")
            return
        if not data.get("techniques"):
            fail("gen-navigator-layer.py: layer without techniques")
    print(f"[generator] ran OK, {len(data.get('techniques', []))} techniques generated")


def main() -> int:
    print(f"== Repository validation: {ROOT} ==")
    validate_skills()
    validate_layer_json()
    validate_generator()
    print(f"\n{checks} check groups executed.")
    if errors:
        print(f"\n[FAIL] {len(errors)} error(s):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("\n[OK] Everything is valid.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

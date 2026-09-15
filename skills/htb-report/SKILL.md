---
name: htb-report
description: >
  Rédaction du rapport final d'une box HTB ou lab autorisé, une fois les flags
  obtenus. À déclencher après htb-privesc (root/SYSTEM) ou en fin d'engagement.
  Produit un rapport Markdown structuré (synthèse, chemin d'attaque, preuves,
  remédiation) convertible en PDF, complémentaire du layer ATT&CK Navigator généré
  par htb-workflow. S'appuie sur notes.md, creds.txt et techniques.txt du dossier
  d'engagement. Produit un livrable narratif prêt à archiver ou partager.
metadata:
  type: reference
  category: reporting
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Rapport final

## Quand utiliser cette skill
Les flags sont récupérés. Objectif : transformer `notes.md` / `creds.txt` /
`techniques.txt` en un rapport lisible qui raconte le chemin d'attaque et fixe
l'apprentissage. Complète le layer ATT&CK Navigator (le « quoi ») par le récit
(le « comment » et le « pourquoi »).

## Structure du rapport (Markdown)

```markdown
# Rapport — <Box> (<IP>)
- **Date** : <date>   **Difficulté** : <Easy/Medium/Hard>   **OS** : <Linux/Windows>
- **Opérateur** : <vous>   **Cadre** : Hack The Box (cible autorisée)

## 1. Synthèse
Résumé en 3-5 lignes : point d'entrée, vecteur de privesc, temps passé.

## 2. Reconnaissance
Ports/services clés (tableau). Ce qui a orienté la suite.

## 3. Chemin d'attaque (étape par étape)
Pour chaque étape : action → résultat → **technique ATT&CK (T####)** → preuve.
| # | Étape | Commande clé | Résultat | ATT&CK |
|---|-------|--------------|----------|--------|
| 1 | Scan | nmap -p- | 80,445 ouverts | T1046 |
| 2 | Web  | ffuf | /admin trouvé | T1595.002 |
| … |      |      |          |        |

## 4. Accès initial (foothold)
Comment le premier shell a été obtenu. Preuve : `id` / `whoami`.

## 5. Élévation de privilèges
Vecteur exact, pourquoi il fonctionnait. Preuve : `id` root / `whoami /priv`.

## 6. Preuves (flags)
- user.txt : `<hash>`
- root.txt : `<hash>`

## 7. Remédiation (défense)
Pour chaque faiblesse exploitée : correctif concret (patch, conf, moindre privilège).

## 8. Annexes
- Couverture ATT&CK : voir `<box>.json` (ATT&CK Navigator).
- Credentials : voir creds.txt (à ne pas diffuser hors contexte autorisé).
```

## Procédure
1. Relire `notes.md` et remplir les sections dans l'ordre du chemin réel.
2. Reporter chaque étape dans le tableau §3 avec son identifiant **T####**
   (mêmes IDs que `techniques.txt` → cohérence avec le layer Navigator).
3. Insérer les preuves minimales (sortie `id`, hash de flag), pas de captures inutiles.
4. Écrire la **remédiation** : c'est ce qui distingue un rapport d'un simple write-up.
5. Générer le layer ATT&CK et le citer en annexe :
   ```bash
   python3 skills/htb-workflow/gen-navigator-layer.py -n "<Box>" -f techniques.txt -o <box>.json
   ```

## Conversion en PDF
```bash
# via pandoc (installer si besoin : apt install pandoc wkhtmltopdf)
pandoc rapport.md -o rapport.pdf --pdf-engine=wkhtmltopdf -V geometry:margin=2cm
# ou en HTML autonome
pandoc rapport.md -o rapport.html -s --toc
```

## Réflexes
- Un bon rapport est **reproductible** : un tiers doit pouvoir rejouer le chemin.
- Toujours inclure la remédiation : l'offensif sans le défensif est incomplet.
- Ne pas diffuser `creds.txt` ni le rapport hors du cadre autorisé.
- Garder la numérotation des techniques alignée avec le layer Navigator.

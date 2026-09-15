---
name: htb-web-enum
description: >
  Énumération d'applications et serveurs web sur une box HTB ou lab autorisé.
  À déclencher dès qu'un port HTTP/HTTPS est ouvert (80, 443, 8080, 8000, 8443…).
  Couvre : fingerprint du serveur (whatweb, nikto), fuzzing de répertoires et
  fichiers (ffuf, feroxbuster, gobuster), énumération de sous-domaines/vhosts,
  scan CMS (wpscan), et détection de vulnérabilités (nuclei). Produit les points
  d'entrée web (pages, paramètres, endpoints, technos) à exploiter ensuite.
metadata:
  type: reference
  category: web
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Énumération web

## Quand utiliser cette skill
Un service HTTP(S) est ouvert. Objectif : identifier la techno, découvrir le
contenu caché (répertoires, fichiers, vhosts), et repérer une faille d'entrée.

## Workflow recommandé
1. **Fingerprint** : quelle stack tourne ? (serveur, langage, CMS)
2. **Contenu caché** : fuzzing de répertoires/fichiers.
3. **Vhosts / sous-domaines** : le vrai contenu est souvent sur `*.machine.htb`.
4. **CMS spécifique** : WordPress → wpscan, etc.
5. **Vulns connues** : nuclei, recherche de CVE sur les versions trouvées.

## Commandes de référence

```bash
IP=10.10.10.10; URL="http://$IP"; DOMAIN="machine.htb"
WL=/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt

# 1) Fingerprint
whatweb "$URL"
nikto -h "$URL" -o nikto.txt

# 2) Fuzzing de répertoires (ffuf) + extensions courantes
ffuf -u "$URL/FUZZ" -w "$WL" -e .php,.html,.txt,.bak -mc 200,204,301,302,307,401,403 -o ffuf.json
# Alternative récursive :
feroxbuster -u "$URL" -w "$WL" -x php,html,txt -o ferox.txt

# 3) Sous-domaines / vhosts (filtrer par taille de réponse -fs)
ffuf -u "$URL" -H "Host: FUZZ.$DOMAIN" \
     -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs 0

# 4) WordPress
wpscan --url "$URL" --enumerate ap,at,u --api-token <token>

# 5) Vulns
nuclei -u "$URL"
```

## Fuzzing de paramètres & API
```bash
# Paramètres GET cachés
ffuf -u "$URL/page.php?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs <taille_base>
```

## Réflexes selon ce qu'on trouve
- **Formulaire de login** → tester defaults, SQLi (`' OR 1=1-- -`), enchaîner brute force (`htb-password-attacks`).
- **Upload de fichier** → tenter un webshell (extensions, double-ext, magic bytes).
- **Paramètre = chemin/fichier** → LFI/RFI, path traversal (`../../etc/passwd`).
- **Version de CMS/plugin** → `searchsploit <produit>` (`htb-exploitation`).
- **Champ reflété** → XSS, SSTI (`{{7*7}}`), injection.

## Astuces
- Ajouter `machine.htb` dans `/etc/hosts` avant le fuzzing de vhosts.
- Toujours filtrer le bruit : `-fs`, `-fc 404`, `-ac` (auto-calibration ffuf).
- Sur HTTPS avec cert bizarre : lire le CN/SAN, il révèle souvent des hostnames.

---
name: htb-web-enum
description: >
  Enumeration of web applications and servers on an HTB box or authorized lab.
  Trigger this as soon as an HTTP/HTTPS port is open (80, 443, 8080, 8000, 8443…).
  Covers: server fingerprinting (whatweb, nikto), directory and file fuzzing
  (ffuf, feroxbuster, gobuster), subdomain/vhost enumeration, CMS scanning
  (wpscan), and vulnerability detection (nuclei). Produces the web entry points
  (pages, parameters, endpoints, technologies) to exploit next.
metadata:
  type: reference
  category: web
  legal: "Authorized targets only (HTB, labs, CTF, systems you own)."
---

# HTB — Web enumeration

## When to use this skill
An HTTP(S) service is open. Goal: identify the technology, discover hidden
content (directories, files, vhosts), and spot an entry-point flaw.

## Recommended workflow
1. **Fingerprint**: what stack is running? (server, language, CMS)
2. **Hidden content**: directory/file fuzzing.
3. **Vhosts / subdomains**: the real content is often on `*.machine.htb`.
4. **Specific CMS**: WordPress → wpscan, etc.
5. **Known vulns**: nuclei, CVE research on the versions found.

## Reference commands

```bash
IP=10.10.10.10; URL="http://$IP"; DOMAIN="machine.htb"
WL=/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt

# 1) Fingerprint
whatweb "$URL"
nikto -h "$URL" -o nikto.txt

# 2) Directory fuzzing (ffuf) + common extensions
ffuf -u "$URL/FUZZ" -w "$WL" -e .php,.html,.txt,.bak -mc 200,204,301,302,307,401,403 -o ffuf.json
# Recursive alternative:
feroxbuster -u "$URL" -w "$WL" -x php,html,txt -o ferox.txt

# 3) Subdomains / vhosts (filter by response size -fs)
ffuf -u "$URL" -H "Host: FUZZ.$DOMAIN" \
     -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -fs 0

# 4) WordPress
wpscan --url "$URL" --enumerate ap,at,u --api-token <token>

# 5) Vulns
nuclei -u "$URL"
```

## Parameter & API fuzzing
```bash
# Hidden GET parameters
ffuf -u "$URL/page.php?FUZZ=test" -w /usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt -fs <base_size>
```

## Reflexes based on what you find
- **Login form** → try defaults, SQLi (`' OR 1=1-- -`), chain into brute force (`htb-password-attacks`).
- **File upload** → attempt a webshell (extensions, double-ext, magic bytes).
- **Parameter = path/file** → LFI/RFI, path traversal (`../../etc/passwd`).
- **CMS/plugin version** → `searchsploit <product>` (`htb-exploitation`).
- **Reflected field** → XSS, SSTI (`{{7*7}}`), injection.

## Tips
- Add `machine.htb` to `/etc/hosts` before vhost fuzzing.
- Always filter the noise: `-fs`, `-fc 404`, `-ac` (ffuf auto-calibration).
- On HTTPS with a weird cert: read the CN/SAN, it often reveals hostnames.

---
name: htb-preflight
description: >
  Contrôle de sécurité et de périmètre AVANT toute action offensive sur une box
  HTB ou lab autorisé. À déclencher au tout début, avant htb-recon, ou quand
  l'agent doute de la cible/de la connectivité. Vérifie : que l'IP cible est bien
  dans le périmètre autorisé, que le VPN HTB (tun0) est monté et fournit le bon
  LHOST, que la cible répond, et prépare le dossier d'engagement. Produit un
  feu vert/rouge et les variables d'environnement (IP, LHOST) pour la suite.
metadata:
  type: reference
  category: safety
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Preflight (périmètre & connectivité)

## Quand utiliser cette skill
En tout premier, avant `htb-recon`. Objectif : garantir qu'on attaque la bonne
cible, par la bonne interface, dans un cadre autorisé. Une erreur ici = scan hors
périmètre ou LHOST erroné (reverse shells qui échouent).

## Garde-fou central
Ne jamais lancer d'action offensive tant que les 3 contrôles ne sont pas verts.
En cas de doute sur l'autorisation, **s'arrêter et demander confirmation**.

## Checklist

### 1) Périmètre autorisé
```bash
IP=10.10.10.10
# Sur HTB, la cible est l'IP de la machine assignée (plage 10.10.10.0/23 ou 10.129.x.x).
case "$IP" in
  10.10.1[0-1].*|10.129.*) echo "[+] Plage HTB plausible" ;;
  10.10.14.*|10.10.16.*)   echo "[-] STOP : c'est VOTRE IP VPN, pas la cible !"; ;;
  *) echo "[!] Hors plage HTB connue — confirmer que la cible est autorisée." ;;
esac
```
Règle : la cible doit être explicitement assignée (HTB), un lab à vous, ou un
système avec autorisation écrite. Rien d'autre.

### 2) VPN HTB monté → LHOST
```bash
if ip -4 addr show tun0 >/dev/null 2>&1; then
  LHOST=$(ip -4 -o addr show tun0 | awk '{print $4}' | cut -d/ -f1)
  echo "[+] VPN up — LHOST=$LHOST (à utiliser pour TOUS les reverse shells)"
else
  echo "[-] tun0 absent : lancez  sudo openvpn <votre>.ovpn  puis relancez."
fi
```
`LHOST` = adresse `tun0`, jamais `eth0`/`wlan0`. La noter une fois pour toutes.

### 3) La cible répond
```bash
ping -c 2 -W 2 "$IP" && echo "[+] Cible joignable" \
  || echo "[!] Pas de réponse ICMP (peut être filtré) — tenter un nmap -Pn"
```

## Préparer le dossier d'engagement
Enchaîner sur le scaffolding (crée notes.md / creds.txt / techniques.txt) :
```bash
./bin/new-box.sh "<Nom>" "$IP" "<hostname.htb>" --hosts
cd ~/htb/<nom>
```

## Sortie attendue
- **Feu vert** : IP dans le périmètre + tun0 up + cible joignable → publier
  `IP` et `LHOST`, créer le dossier, passer à `htb-recon`.
- **Feu rouge** : au moins un contrôle échoue → expliquer lequel et l'action
  corrective, ne pas lancer de scan.

## Réflexes
- Confondre son IP VPN et l'IP cible est l'erreur n°1 : la skill le détecte.
- Si `ping` échoue mais que le VPN est up, continuer avec `nmap -Pn` plutôt que
  conclure « cible morte ».
- Vérifier l'heure système ici évite les erreurs Kerberos plus tard (voir
  `htb-active-directory`).

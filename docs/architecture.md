# Architecture — Homelab PME

Ce document décrit le plan d'adressage IP, la convention de nommage et l'inventaire
des machines de l'infrastructure. Toute l'infra est virtualisée sous VMware
Workstation Pro sur un unique PC hôte Windows.

## Réseau

| Élément | Valeur |
| --- | --- |
| Réseau LAN | `10.10.10.0/24` |
| Passerelle (OPNsense) | `10.10.10.254` |
| Plage DHCP (fournie par OPNsense) | `10.10.10.100` → `10.10.10.200` |
| Domaine Active Directory | `lab.local` (NetBIOS : `LAB`) |
| WAN OPNsense | VMware NAT (VMnet8) |
| LAN OPNsense | VMware Host-only (VMnet2) |

Les adresses des serveurs sont **fixes** et choisies **hors** de la plage DHCP
(`.100`–`.200`) afin d'éviter tout conflit d'attribution.

## Convention de nommage

Format : **`RÔLE-DESCRIPTION-NUMÉRO`**

- **RÔLE** : fonction principale de la machine (`FW` pare-feu, `SRV` serveur, `PC` poste).
- **DESCRIPTION** : rôle applicatif (`OPN` OPNsense, `AD` Active Directory, `WEB` services web).
- **NUMÉRO** : incrément à deux chiffres (`01`, `02`, …).

Exemples : `FW-OPN-01`, `SRV-AD-01`, `SRV-WEB-01`, `PC-WIN11-01`.

## Inventaire des machines

| Nom | Rôle | OS | Adresse IP | Notes |
| --- | --- | --- | --- | --- |
| `FW-OPN-01` | Pare-feu / routeur | OPNsense | `10.10.10.254` (LAN) | DHCP, DNS, NAT ; WAN sur VMnet8 |
| `SRV-AD-01` | Contrôleur de domaine | Windows Server 2025 | `10.10.10.10` | AD DS + DNS ; forêt `lab.local` |
| `SRV-WEB-01` | Serveur de services | Ubuntu Server 26.04 | `10.10.10.20` | Docker, Portainer, monitoring, NPM, Restic |
| `PC-WIN11-01` | Poste client | Windows 11 Pro | DHCP (`.100`–`.200`) | Joint au domaine `lab.local` ; GPO appliquées |

## Services hébergés sur SRV-WEB-01

| Service | Port(s) | Accès | Rôle |
| --- | --- | --- | --- |
| Portainer | `9443` | `https://10.10.10.20:9443` | Gestion visuelle de Docker |
| Grafana | `3000` | `http://10.10.10.20:3000` | Tableaux de bord (dashboard ID 1860) |
| Prometheus | `9090` | interne | Collecte des métriques |
| node-exporter | `9100` | interne | Métriques système |
| Nginx Proxy Manager | `80` / `443` / `81` | `http://10.10.10.20:81` (admin) | Reverse proxy (ex. `grafana.lab.local`) |

## Notes de résolution DNS

- `PC-WIN11-01` utilise le DC (`10.10.10.10`) comme DNS primaire (indispensable pour AD).
- Les noms internes type `grafana.lab.local` sont résolus côté poste via le fichier
  `hosts` en attendant une entrée DNS dédiée sur le DC.
- Le DC utilise des forwarders (`1.1.1.1`, `9.9.9.9`) pour la résolution externe.

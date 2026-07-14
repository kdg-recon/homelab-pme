# 🖥️ Homelab PME — Infrastructure simulée d'une entreprise de 50 salariés

Projet personnel de montée en compétences en **administration systèmes, réseau et sécurité**.
L'objectif : concevoir, déployer et documenter **de zéro** l'infrastructure informatique
d'une PME fictive de 50 salariés, entièrement virtualisée sur une seule machine.

Ce dépôt sert de **portfolio** : il retrace les choix d'architecture, les configurations,
les incidents rencontrés et leur résolution, ainsi que la feuille de route.

> 🔒 **Sécurité** — Aucun secret n'est versionné dans ce dépôt : mots de passe,
> clés privées SSH, jetons et mots de passe Restic/DSRM/Administrator sont exclus
> via `.gitignore`. Les fichiers de configuration publiés utilisent des *placeholders*
> et un `.env.example` ; les vraies valeurs restent hors dépôt.

---

## 🏗️ Architecture réseau

```
Internet
   │
   ▼
[ FW-OPN-01 / OPNsense ]   WAN = VMware NAT (VMnet8)
   │                       LAN = VMware Host-only (VMnet2)
   ▼
LAN plat — 10.10.10.0/24   (passerelle OPNsense : 10.10.10.254)
   ├── SRV-AD-01     10.10.10.10   Windows Server 2025 — AD DS / DNS
   ├── SRV-WEB-01    10.10.10.20   Ubuntu Server 26.04 — Docker & services
   ├── PC-WIN11-01   DHCP          Windows 11 Pro — poste joint au domaine
   └── DHCP OPNsense 10.10.10.100 → 10.10.10.200
```

Détail complet du plan d'adressage et de la convention de nommage :
voir [`docs/architecture.md`](./docs/architecture.md).

---

## 🧰 Stack technique

### Virtualisation
- **VMware Workstation Pro** (hyperviseur de type 2, sur PC Windows 32 Go de RAM).
- Réseaux virtuels : NAT (VMnet8) pour le WAN, Host-only (VMnet2) pour le LAN.

### Réseau / pare-feu — OPNsense (FW-OPN-01)
- Passerelle entre le LAN et Internet.
- **DHCP** (plage 10.10.10.100–200), **DNS** (forwarders) et **NAT** sortant.

### Serveur Linux — Ubuntu Server 26.04 durci (SRV-WEB-01)
- IP fixe via **netplan**, hors plage DHCP.
- **Authentification SSH par clé ed25519** ; mot de passe et login root désactivés.
- **UFW** : politique « deny incoming / allow outgoing », SSH en mode `limit`.
- **Fail2Ban** : jail `sshd` (backend systemd, banaction UFW), réseau labo en liste blanche.

### Active Directory — Windows Server 2025 (SRV-AD-01)
- Rôles **AD DS** + **DNS**, forêt `lab.local` (NetBIOS `LAB`).
- **Unités d'organisation (OU)** : Utilisateurs (IT, RH, Compta), Groupes, Ordinateurs.
- Création scriptée en **PowerShell** (`New-ADOrganizationalUnit`).
- **Utilisateurs, groupes et GPO** appliqués sur les OU.

### Poste client — Windows 11 Pro (PC-WIN11-01)
- Édition **Pro** (requise pour la jonction), UEFI + Secure Boot + vTPM.
- **Joint au domaine `lab.local`** ; DNS pointé sur le contrôleur de domaine.
- **GPO** appliquée et vérifiée (bandeau d'avertissement au login).

### Conteneurs & services (SRV-WEB-01)
- **Docker Engine** (dépôt officiel) + plugin Compose.
- **Portainer** — gestion visuelle des conteneurs (Docker Compose).
- **Monitoring** — **Prometheus** (collecte) + **Grafana** (dashboards, ID 1860)
  + **node-exporter** (métriques système).
- **Nginx Proxy Manager** — reverse proxy (ex. `grafana.lab.local`), point d'entrée unique.

### Sauvegardes — Restic (SRV-WEB-01)
- Dépôt **chiffré** local, mot de passe stocké hors serveur.
- **Test de restauration réussi**.
- **Automatisé via systemd** : service + timer (sauvegarde nocturne 02h30, rotation
  keep-daily/weekly/monthly + prune).

---

## 🛠️ Incidents résolus

### 🔧 Étude de cas — Bug réseau `e1000e` sous VMware (TCP cassé entre VM)
- **Symptôme** : jonction au domaine impossible ; **tout le TCP échouait** entre VM,
  alors que le **ping (ICMP) et le DNS (UDP) fonctionnaient**.
- **Diagnostic par couches** : DNS/résolution OK → service SMB & port 445 en écoute →
  règles pare-feu → pare-feux Windows désactivés des deux côtés → routage, ARP,
  tracert sains → offload sans effet → test depuis l'hôte : TCP 445 échoue aussi
  → cause isolée à la **carte réseau du DC en réception**.
- **Cause racine** : la carte virtuelle émulée **`e1000e`** de VMware corrompt les
  paquets TCP entrants (bug connu) ; ICMP/UDP non affectés.
- **Correction** : bascule **`e1000e` → `vmxnet3`** (édition du fichier `.vmx`) +
  réattribution de l'IP fixe du contrôleur de domaine → jonction réussie.
- **Leçons** : diagnostiquer méthodiquement par couches ; toujours vérifier `hostname`
  (piège hôte/invité) ; tester une hypothèse avant de corriger.

---

## 🚀 À venir

- **VPS** — accès distant, réplication hors-site des sauvegardes, HTTPS public.
- **Vaultwarden** — gestionnaire de mots de passe auto-hébergé.
- **Wazuh / Suricata** — détection d'intrusion (HIDS / NIDS) et supervision sécurité.
- **Ansible** — automatisation et infrastructure as code.
- **VLAN** — segmentation réseau (séparation des services / départements).
- **WireGuard** — VPN moderne pour l'accès distant sécurisé au LAN.

---

## 📁 Organisation du dépôt

```
homelab-pme/
├── README.md            Ce fichier — vue d'ensemble du projet
├── JOURNAL.md           Journal de bord chronologique et détaillé
├── docs/                Documentation (architecture, plan IP, nommage, procédures)
├── docker/              Fichiers docker-compose.yml (portainer, monitoring, npm)
└── scripts/             Scripts d'exploitation (ex. backup-lab.sh)
```

---

*Projet réalisé dans un cadre d'apprentissage. Toute l'infrastructure est virtualisée
et isolée sur un réseau de laboratoire.*

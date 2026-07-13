# 🖥️ Homelab PME — Infrastructure simulée d'une entreprise de 50 salariés

Projet personnel de montée en compétences en **administration systèmes, réseau et sécurité**.
L'objectif : concevoir, déployer et documenter **de zéro** l'infrastructure informatique
d'une PME fictive de 50 salariés, entièrement virtualisée sur une seule machine.

Ce dépôt sert de **portfolio** : il retrace les choix d'architecture, les configurations,
les incidents rencontrés et leur résolution, ainsi que la feuille de route.

> 🔒 **Sécurité** — Aucun secret n'est versionné dans ce dépôt : mots de passe,
> clés privées SSH et certificats sont exclus via `.gitignore` et stockés hors dépôt.

---

## 🏗️ Architecture réseau

```
Internet
   │
   ▼
[ OPNsense ]  WAN = VMware NAT (VMnet8)
   │          LAN = VMware Host-only (VMnet2)
   ▼
LAN plat — 10.10.10.0/24   (passerelle OPNsense : 10.10.10.254)
   ├── SRV-AD-01     10.10.10.10   (Windows Server 2025 — AD DS / DNS)
   ├── SRV-WEB-01    10.10.10.20   (Ubuntu Server — durci)
   ├── PC-WIN11-01   DHCP          (Windows 11 Pro — poste client)
   └── DHCP OPNsense 10.10.10.100 → 10.10.10.200
```

Convention de nommage : `RÔLE-DESCRIPTION-NUMÉRO` (ex. `FW-OPN-01`, `SRV-AD-01`).

---

## 🧰 Stack technique

### Virtualisation
- **VMware Workstation Pro** (hyperviseur de type 2, sur PC Windows 32 Go de RAM).
- Réseaux virtuels : NAT (VMnet8) pour le WAN, Host-only (VMnet2) pour le LAN.

### Pare-feu / routeur — OPNsense
- Rôle de passerelle entre le LAN et Internet.
- **DHCP** pour les postes clients (plage 10.10.10.100–200).
- **DNS** (forwarders) et **NAT** sortant.

### Serveur Linux — Ubuntu Server (SRV-WEB-01)
Machine durcie selon les bonnes pratiques :
- IP fixe via **netplan**, hors plage DHCP.
- **Authentification SSH par clé ed25519** ; mot de passe et login root désactivés.
- **UFW** : politique « deny incoming / allow outgoing », SSH en mode `limit`.
- **Fail2Ban** : jail `sshd` (backend systemd, banaction UFW), réseau labo en liste blanche.

### Active Directory — Windows Server 2025 (SRV-AD-01)
- Rôles **AD DS** + **DNS**, nouvelle forêt `lab.local` (NetBIOS `LAB`).
- **Unités d'organisation (OU)** : Utilisateurs (IT, RH, Compta), Groupes, Ordinateurs.
- Création scriptée en **PowerShell** (`New-ADOrganizationalUnit`).
- **Utilisateurs, groupes et GPO** appliqués sur les OU.

### Poste client — Windows 11 Pro (PC-WIN11-01)
- Édition **Pro** (requise pour la jonction de domaine), UEFI + Secure Boot + vTPM.
- DNS pointé sur le contrôleur de domaine, en cours de jonction à `lab.local`.

---

## 🛠️ Incidents résolus

### Bug réseau `e1000e` sous VMware — TCP cassé entre VM
- **Symptôme** : communication TCP défaillante entre machines virtuelles
  (connexions qui se figent / échouent), alors que le ping passait.
- **Diagnostic** : problème connu de la carte réseau virtuelle émulée `e1000e`
  (offloading / checksum) sous VMware.
- **Résolution** : bascule de l'adaptateur virtuel de **`e1000e` vers `vmxnet3`**
  (pilote paravirtualisé VMware) → trafic TCP stable rétabli.

---

## 🚀 À venir

- **Docker** — conteneurisation de services (ex. serveur web, applications internes).
- **Monitoring** — supervision (métriques, logs, alertes).
- **Sauvegardes** — stratégie de backup et tests de restauration.
- **VLAN** — segmentation réseau (séparation des services/départements).
- **VPN** — accès distant sécurisé au LAN.
- **Automatisation** — scripts / infrastructure as code pour reproduire l'infra.

---

## 📓 Journal de bord

Le fichier [`JOURNAL.md`](./JOURNAL.md) retrace jour par jour les étapes,
décisions techniques et vérifications effectuées.

---

*Projet réalisé dans un cadre d'apprentissage. Toute l'infrastructure est virtualisée
et isolée sur un réseau de laboratoire.*

# Journal de bord — Homelab PME

## 2026-07-11 — Jour 1 : mise en place
- Objectif : monter une infra complète de PME pour monter en compétence
  (admin systèmes / réseau / sécurité).
- Matériel : PC Windows, 32 Go de RAM, machine unique.
- Décision : hyperviseur = VMware Workstation Pro (type 2, gratuit),
  au lieu de Proxmox — car machine unique sous Windows qu'on veut garder.
- Prochaine étape : installer VMware et créer la première VM.

## Plan initial du réseau (Phase 1 — mis à jour)
- Topologie : Internet → OPNsense → LAN plat (10.10.10.0/24).
- WAN d'OPNsense = réseau VMware NAT (VMnet8).
- LAN d'OPNsense = réseau VMware Host-only (VMnet2), DHCP VMware désactivé.
- Passerelle OPNsense (LAN) : 10.10.10.254  ← décalé depuis .1
  (car VMware attribue .1 au PC hôte sur ce réseau).
- PC Windows (hôte) sur le LAN : 10.10.10.1
- Adresses fixes serveurs : SRV-AD-01 = .10 | SRV-WEB-01 = .20
- Plage DHCP fournie par OPNsense : 10.10.10.100 à 10.10.10.200
- Nommage : RÔLE-DESCRIPTION-NUMÉRO (ex. FW-OPN-01).

## Phase 5 — Ubuntu Server déployé (SRV-WEB-01)
- OS : Ubuntu Server 26.04 LTS dans VMware, carte unique sur VMnet2 (LAN).
- DHCP OK : adresse 10.10.10.123 reçue automatiquement d'OPNsense
  → preuve que le réseau et le routage fonctionnent.
- Accès Internet et DNS vérifiés (ping via OPNsense).
- OpenSSH installé : accès distant depuis Windows via `ssh user@10.10.10.123`.
- Système mis à jour (apt update && apt upgrade).
- À faire bientôt : lui donner une adresse fixe/permanente (.20 prévu au plan).

## SRV-WEB-01 — passage en IP fixe
- Adresse statique 10.10.10.20/24 via netplan (00-installer-config.yaml).
- Passerelle 10.10.10.254 (OPNsense), DNS 10.10.10.254 + 1.1.1.1.
- .20 choisie hors plage DHCP (.100-.200) pour éviter tout conflit.
- Accès SSH stable : ssh kevin@10.10.10.20.

## SRV-WEB-01 — durcissement SSH
- Authentification par clé ed25519 (clé privée sur le PC Windows, protégée par passphrase).
- Mot de passe SSH désactivé (PasswordAuthentication no) via /etc/ssh/sshd_config.d/00-hardening.conf.
- Connexion root directe interdite (PermitRootLogin no).
- Vérifié : connexion par clé OK, connexion sans clé refusée (publickey).

## SRV-WEB-01 — pare-feu UFW
- UFW activé : deny incoming / allow outgoing par défaut.
- Seul le SSH est autorisé, en mode "limit" (anti-brute force basique).
- Vérifié : reconnexion SSH OK avec le pare-feu actif.

## SRV-WEB-01 — Fail2Ban
- Fail2Ban installé, jail sshd active.
- backend = systemd (obligatoire sur Ubuntu récent, sinon lecture des logs KO).
- banaction = ufw (bannissements appliqués via le pare-feu existant).
- 3 échecs / 10 min → ban 1 h. Réseau labo (10.10.10.0/24) en liste blanche.
- Testé : bannissement manuel d'une IP OK.

## SRV-AD-01 — Windows Server 2025 installé
- Édition : Standard (Desktop Experience), UEFI + Secure Boot.
- Carte unique sur VMnet2 (LAN).
- IP fixe : 10.10.10.10/24, passerelle 10.10.10.254 (OPNsense).
- DNS pointé sur lui-même (127.0.0.1) en prévision du rôle DNS/AD.
- Machine renommée SRV-AD-01.
- Mot de passe Administrator défini et stocké en lieu sûr.

## SRV-AD-01 — Promotion contrôleur de domaine
- Rôle AD DS + DNS installés.
- Nouvelle forêt / domaine : lab.local (NetBIOS : LAB).
- DNS installé sur le DC (le serveur se résout via 127.0.0.1).
- Mot de passe DSRM défini et stocké en lieu sûr.
- Avertissement délégation DNS : normal en labo (pas de zone parente).
- Connexion désormais en LAB\Administrator (compte de domaine).

## lab.local — arborescence des OU
- OU racine LAB, puis Utilisateurs (IT, RH, Compta), Groupes, Ordinateurs (Postes, Serveurs).
- Créées en une passe via PowerShell (New-ADOrganizationalUnit).
- Rappel : GPO applicables sur les OU, pas sur les containers Users/Computers par défaut.

## Astuce — VMware Tools
- Copier-coller hôte↔VM et affichage adaptatif nécessitent les VMware Tools.
- Installés sur SRV-AD-01 (VM → Install VMware Tools → setup64.exe → reboot).
- À installer sur chaque VM Windows. Équivalent Linux : open-vm-tools.

## PC-WIN11-01 — Windows 11 Pro installé
- Édition Pro (obligatoire pour rejoindre le domaine), UEFI + Secure Boot + vTPM.
- Carte sur VMnet2 (LAN). Compte local "localadmin" créé (compte Microsoft évité).
- VMware Tools installés.
- Pas encore joint au domaine (prochaine étape : DNS puis jonction).

## Réseau — DNS pour le domaine
- DC (SRV-AD-01) : forwarders DNS 1.1.1.1 + 9.9.9.9 ajoutés.
- PC-WIN11-01 : DNS manuel = 10.10.10.10 (le DC), aucun DNS secondaire.
- Vérifié : nltest /dsgetdc:lab.local trouve \\SRV-AD-01, Internet OK.
- À faire : distribuer le DNS du DC via le DHCP d'OPNsense (centralisation).


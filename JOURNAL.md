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

## Incident majeur — jonction domaine impossible (bug e1000e)
### Symptôme
- Add-Computer échoue : "The specified network name is no longer available".
- Ping (ICMP) et DNS (UDP) OK, mais TOUT le TCP échoue entre les VM.

### Démarche de diagnostic (par couches)
- DNS/nltest : OK (\\SRV-AD-01 trouvé) → pas un souci de résolution.
- Service SMB (LanmanServer) : Running ; port 445 en écoute côté DC.
- Règles pare-feu SMB-In : activées ; profils pare-feu : NotConfigured.
- Pare-feux Windows désactivés des 2 côtés → TCP échoue toujours.
- Routage (NextHop 0.0.0.0), ARP, tracert (1 saut) : réseau L2/L3 sain.
- Offload désactivé : sans effet.
- Test depuis l'HÔTE (autre type de carte) : TCP 445 échoue aussi
  → cause isolée = carte réseau du DC en réception.

### Cause racine
- Carte virtuelle émulée "e1000e" de VMware : corrompt les paquets TCP
  entrants (bug connu). ICMP/UDP non affectés.

### Correction
- Bascule carte e1000e -> vmxnet3 (edit .vmx : ethernet0.virtualDev).
- Réattribution de l'IP fixe 10.10.10.10 sur la nouvelle carte du DC.
- Poste W11 : idem vmxnet3 (DHCP, donc pas de reconfig IP).
- Jonction au domaine réussie.

### Leçons
- Diagnostiquer par couches, du bas vers le haut.
- Tester TOUJOURS au bon endroit (piège hôte/invité → réflexe `hostname`).
- Une hypothèse se teste et s'abandonne si les faits l'infirment.

## PC-WIN11-01 — jonction au domaine + première GPO
- Poste effectivement JOINT au domaine lab.local (débloqué après l'incident e1000e).
- Ouverture de session en compte de domaine LAB\... validée.
- Première GPO créée puis liée à l'OU des postes.
- Test concret : bandeau d'avertissement légal affiché à l'écran de connexion
  (message d'ouverture de session interactive).
- Vérifié : `gpupdate /force` puis reboot → le bandeau apparaît
  → preuve que la stratégie descend bien du DC vers le poste client.

## Versionnement — Git & GitHub
- Projet mis sous versionnement Git : dépôt local initialisé, branche principale `main`.
- `.gitignore` de sécurité : exclut clés privées SSH, *.key/*.pem/*.env, dossiers
  secrets/, fichiers système Windows et l'ISO OPNsense (trop lourde pour Git).
- Premier commit (README + JOURNAL + .gitignore), puis publication sur GitHub :
  dépôt public servant de portfolio → https://github.com/kdg-recon/homelab-pme
- Authentification par jeton personnel (PAT) : un SECRET, jamais committé.
- Cycle de travail retenu : `git add .` → `git commit -m "..."` → `git push`.

## SRV-WEB-01 — Docker installé
- Docker Engine (dépôt officiel) + Compose plugin sur Ubuntu 26.04.
- Utilisateur kevin ajouté au groupe docker (plus besoin de sudo).
- Test hello-world OK : cycle image -> pull -> conteneur compris.

## SRV-WEB-01 — premier conteneur applicatif
- nginx lancé via `docker run -d -p 8080:80 nginx`, accessible sur http://10.10.10.20:8080.
- Notions vues : image/conteneur, -d, --name, redirection de port -p, docker ps/stop/rm.
- ⚠️ Sécurité notée : Docker contourne UFW (iptables direct). À corriger via ufw-docker / reverse proxy.

## SRV-WEB-01 — Portainer (gestion visuelle de Docker)
- Portainer déployé via Docker Compose (pile ~/docker/portainer).
- Interface web : gestion des conteneurs, images, volumes et réseaux sans ligne de commande.
- Accès https://10.10.10.20:9443 (compte admin créé au 1er lancement).
- Utilité : vue d'ensemble + actions rapides (logs, redémarrage, inspection).

## SRV-WEB-01 — stack de monitoring (Compose multi-services)
- 3 conteneurs : node-exporter (capteur), prometheus (collecte), grafana (affichage).
- Réseau Docker auto : les services se joignent par leur NOM (node-exporter, prometheus).
- Grafana http://10.10.10.20:3000, source Prometheus (http://prometheus:9090).
- Dashboard "Node Exporter Full" (ID 1860) importé : CPU/RAM/disque/réseau en temps réel.
- Volumes nommés pour la persistance des données.

## SRV-WEB-01 — reverse proxy (Nginx Proxy Manager)
- NPM déployé (ports 80/443 + admin 81), pile ~/docker/npm.
- Proxy Host : grafana.lab.local -> 10.10.10.20:3000.
- Résolution via fichier hosts Windows (10.10.10.20 grafana.lab.local ...).
- HTTPS reconnu : reporté (Let's Encrypt = domaine public requis, ou CA interne).
- Concept : point d'entrée unique, accès par nom, SSL centralisé.

## SRV-WEB-01 — sauvegardes (Restic)
- Restic installé. Dépôt chiffré local : /srv/backups/restic-repo.
- Mot de passe de dépôt stocké HORS serveur (gestionnaire de mots de passe).
- Sauvegarde de /home/kevin/docker et /etc (snapshots datés).
- ✅ Test de restauration RÉUSSI : fichier supprimé puis récupéré.
- À venir : planification (timer), hors-site vers VPS (SFTP), données des volumes Docker.

## SRV-WEB-01 — sauvegardes automatisées
- Script /usr/local/bin/backup-lab.sh (backup + rotation keep-daily/weekly/monthly + prune).
- Automatisation via systemd : backup-lab.service (quoi) + backup-lab.timer (quand : 02h30/nuit).
- Persistent=true : rattrapage si serveur éteint. Vérif via journalctl -u backup-lab.service.
- À venir : réplication hors-site vers le VPS (SFTP).

## SRV-ANSIBLE-01 — idempotence validée
- 2e exécution de durcissement.yml : ok=8, changed=0, failed=0. ✅
- Concept ancré : Ansible décrit un ÉTAT, compare, et n'agit que sur l'écart.
  Rejouable à l'infini sans risque → automatisation sûre.
- Valeur démontrée : détection + correction auto d'une dérive réelle (ssh disabled).

## Ansible — parc multi-machines
- Inventaire enrichi : groupes webservers + control, groupe parent [linux:children].
- ansible_python_interpreter figé (fin des warnings).
- Playbook joué sur 2 machines : srv-ansible-01 (changed=4, machine vierge durcie
  automatiquement) / srv-web-01 (changed=0, déjà conforme).
- Correction sudo-rs encodée dans le playbook (module alternatives) => reproductible.
- Preuve : un même fichier fait converger un parc hétérogène vers l'état voulu.

## Ansible — durcissement SSH encodé
- Tâche copy : dépôt de /etc/ssh/sshd_config.d/00-hardening.conf (clé-only, no root).
- validate: sshd -t => Ansible refuse d'écrire une config invalide (garde-fou).
- Handler "Redemarrer SSH" : déclenché UNIQUEMENT si le fichier change (notify).
- Résultat : srv-ansible-01 durci automatiquement, srv-web-01 inchangé.


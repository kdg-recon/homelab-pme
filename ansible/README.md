# ansible/ — Automatisation (Infrastructure as Code)

Playbook de **durcissement de base** des serveurs Linux du homelab, piloté depuis un
control node dédié. L'objectif : appliquer une configuration de sécurité **reproductible**
et **documentée** sur toutes les machines, plutôt que des réglages manuels non traçables.

## Le control node — SRV-ANSIBLE-01 (10.10.10.30)

Ansible est **agentless** : il n'y a **rien à installer sur les machines cibles**. Le
control node (**SRV-ANSIBLE-01**, `10.10.10.30`, utilisateur `kevin`) se connecte à
chaque cible en **SSH** (par clé ed25519) et y exécute les tâches à distance, en
s'appuyant sur Python déjà présent sur les cibles. On administre donc tout le parc
depuis un seul poste, sans agent ni démon à maintenir côté serveurs.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `inventory.ini` | Inventaire : groupes `webservers` et `control`, réunis dans le groupe parent `[linux:children]`. |
| `durcissement.yml` | Playbook appliqué au groupe `linux`. |

## Lancer le playbook

Depuis le control node, dans `/home/kevin/ansible/` :

```bash
ansible-playbook -i inventory.ini durcissement.yml -K
```

- `-i inventory.ini` : indique l'inventaire (quelles machines, quels groupes).
- `durcissement.yml` : le playbook à exécuter.
- `-K` (`--ask-become-pass`) : demande le mot de passe `sudo` **au lancement** — il
  n'est donc **jamais stocké** dans un fichier du dépôt.

## Idempotence

Un playbook Ansible décrit un **état cible**, pas une suite d'actions. À chaque tâche,
Ansible vérifie d'abord si l'état est déjà atteint : si oui, il ne fait rien (`ok`) ;
sinon, il applique le changement (`changed`). Conséquence : on peut **rejouer** le
playbook autant de fois qu'on veut **sans risque** ni effet de bord — seul ce qui
diffère de l'état voulu est modifié.

## Ce que fait `durcissement.yml`

1. Met à jour le cache APT et installe `fail2ban`, `ufw`, `unattended-upgrades`.
2. Configure UFW : SSH en mode `limit`, refus de tout l'entrant, puis activation.
3. Active `fail2ban` et `ssh` au démarrage (systemd).
4. Bascule `sudo-rs` vers le `sudo` classique (compatibilité Ansible — voir incidents).
5. Déploie les clés publiques d'administration (`authorized_key`).
6. Dépose une config SSH durcie (`/etc/ssh/sshd_config.d/00-hardening.conf` : clé
   uniquement, `PermitRootLogin no`), **validée** par `sshd -t` avant application,
   avec un **handler** qui redémarre SSH uniquement si le fichier a changé.

## 🛠️ Incidents résolus

### (a) UFW bannissait le control node
La règle `limit` sur OpenSSH considérait le control node comme un attaquant : en
rejouant le playbook, Ansible ouvre plusieurs connexions SSH rapprochées, ce que le
rate-limit d'UFW (≈ 6 connexions / 30 s) interprète comme du brute-force → connexions
bloquées.
**Correctif :** autoriser explicitement le control node —
`ufw allow from 10.10.10.30` — pour l'exempter du rate-limit.

### (b) Incompatibilité `sudo-rs` (Ubuntu 26.04)
Ubuntu 26.04 fournit `sudo-rs` (réécriture en Rust) par défaut, dont le comportement
d'escalade de privilèges cassait le `become: true` d'Ansible.
**Correctif :** repasser sur le `sudo` classique via
`update-alternatives --set sudo /usr/bin/sudo.ws`. Ce correctif est désormais **encodé
dans le playbook** (tâche `alternatives`) pour être appliqué automatiquement partout.

### (c) Auto-verrouillage SSH (leçon sur l'ordre des tâches)
Le playbook a appliqué `PasswordAuthentication no` sur une machine où ma clé publique
Windows n'était **pas encore déployée** → plus aucun moyen de me connecter, accès coupé.
Réparé via la **console VMware** (accès hors-réseau).
**Correctif durable :** placer la tâche `authorized_key` (dépôt des clés) **AVANT** le
durcissement SSH. L'**ordre des tâches** devient ici une règle de sécurité : on
s'assure d'avoir une porte d'entrée valide *avant* de fermer les autres.

## 🚀 Pistes d'amélioration

- **ansible-vault** — chiffrer d'éventuels secrets (mots de passe, tokens) pour pouvoir
  les versionner sans risque.
- **Compte de service dédié** — un utilisateur d'automatisation distinct de `kevin`,
  aux privilèges limités et traçables.
- **Rôles Ansible** — factoriser le playbook en rôles réutilisables (structure
  `roles/`), plus maintenable qu'un playbook monolithique.
- **Machines Windows (WinRM)** — étendre l'automatisation aux serveurs/postes Windows
  via WinRM (configuration de base, jonction de domaine, etc.).

## 🔒 Sécurité

Aucun secret n'est versionné : l'inventaire ne contient aucun mot de passe, le mot de
passe `sudo` est saisi à l'exécution (`-K`), et l'authentification aux cibles se fait
par **clé SSH** — la clé **privée** reste hors dépôt (exclue par le `.gitignore`).
Seules les clés **publiques** (`.pub`), qui ne sont pas des secrets, peuvent l'être.

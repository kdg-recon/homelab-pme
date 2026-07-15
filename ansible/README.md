# ansible/ — Automatisation du durcissement (Ansible)

Configuration Ansible utilisée pour **durcir automatiquement** les serveurs Linux
du homelab, de façon reproductible et idempotente.

## 🎛️ Control node — SRV-ANSIBLE-01

Le *control node* est la machine depuis laquelle Ansible est exécuté :
**SRV-ANSIBLE-01** (`10.10.10.30`, utilisateur `kevin`).

- Ansible n'a besoin d'être installé **que** sur le control node.
- Il pilote les serveurs cibles **par SSH** (avec la clé ed25519), sans agent à installer côté cible.
- Les cibles sont décrites dans [`inventory.ini`](./inventory.ini) ; les actions dans
  [`durcissement.yml`](./durcissement.yml).

## 📂 Fichiers

| Fichier | Rôle |
| --- | --- |
| `inventory.ini` | Inventaire : hôtes (`webservers`, `control`) et variables (`ansible_user`). |
| `durcissement.yml` | Playbook de durcissement de base des serveurs Linux. |

## ▶️ Lancer le playbook

Depuis le control node, dans `/home/kevin/ansible/` :

```bash
ansible-playbook -i inventory.ini durcissement.yml -K
```

- `-i inventory.ini` — indique l'inventaire (la liste des machines à configurer).
- `durcissement.yml` — le playbook à exécuter.
- `-K` — demande le mot de passe *sudo* (`--ask-become-pass`) au lancement, car les
  tâches sont en `become: true`. **Le mot de passe n'est jamais stocké dans les fichiers.**

## 🛡️ Ce que fait le playbook

- Met à jour le cache APT et installe `fail2ban`, `ufw`, `unattended-upgrades`.
- Configure **UFW** : SSH en mode `limit`, politique « deny incoming », pare-feu activé.
- Active **fail2ban** et **ssh** au démarrage (systemd).
- Bascule `sudo-rs` vers le `sudo` classique (compatibilité — voir incidents).
- Dépose une **config SSH durcie** (`/etc/ssh/sshd_config.d/00-hardening.conf` :
  clé uniquement, pas de mot de passe, pas de root) avec validation `sshd -t`,
  puis **redémarre SSH** via un *handler* (uniquement si le fichier a changé).

## 🛠️ Incidents résolus

### 1. UFW `limit` bannit le control node
- **Symptôme** : après activation de la règle UFW `limit` sur SSH, le control node
  se retrouvait bloqué au bout de quelques connexions Ansible rapprochées
  (le rate-limiting compte les connexions répétées comme une attaque par force brute).
- **Cause** : Ansible ouvre de nombreuses connexions SSH successives ; le mode `limit`
  d'UFW (≈ 6 connexions / 30 s) les interprète comme du brute-force et bannit l'IP source.
- **Résolution** : exclure l'IP du control node du rate-limiting (règle d'autorisation
  explicite pour `10.10.10.30` **avant** la règle `limit`, ou réutilisation du multiplexage
  SSH / `ControlPersist`), afin qu'Ansible ne soit plus compté comme un attaquant.

### 2. Incompatibilité `sudo-rs` sur Ubuntu 26.04
- **Symptôme** : les tâches en `become: true` échouaient — Ubuntu 26.04 fournit par
  défaut **`sudo-rs`** (réécriture en Rust), dont le comportement diffère de `sudo`
  et casse l'élévation de privilèges attendue par Ansible.
- **Résolution** : rebasculer sur le `sudo` classique via **`update-alternatives`**
  (le playbook applique `alternatives: name=sudo path=/usr/bin/sudo.ws`), rétablissant
  un `sudo` compatible.

## 🔒 Sécurité

Aucun secret n'est versionné : l'inventaire ne contient pas de mot de passe, le
mot de passe *sudo* est saisi à l'exécution (`-K`), et l'authentification aux cibles
se fait par **clé SSH** (jamais copiée dans le dépôt, exclue par le `.gitignore`).

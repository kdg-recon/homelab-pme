# scripts/ — Scripts d'exploitation

Scripts utilisés sur **SRV-WEB-01** (`10.10.10.20`).

| Script | Emplacement sur le serveur | Rôle |
| --- | --- | --- |
| `backup-lab.sh` | `/usr/local/bin/backup-lab.sh` | Sauvegarde Restic + rotation (keep-daily/weekly/monthly) + prune |

## 🔒 Secrets

Le script ne doit contenir **aucun mot de passe en clair**. Le mot de passe du dépôt
Restic est fourni via une variable d'environnement / un fichier lu au moment de
l'exécution (référencé par le service systemd), jamais écrit dans le script versionné.

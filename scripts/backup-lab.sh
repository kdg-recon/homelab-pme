#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="/srv/backups/restic-repo"
export RESTIC_PASSWORD_FILE="/root/.restic-pass"

# Sauvegarde
restic backup /home/kevin/docker /etc --tag auto

# Rotation : on garde 7 sauvegardes quotidiennes, 4 hebdo, 6 mensuelles
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

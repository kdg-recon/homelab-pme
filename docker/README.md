# docker/ — Piles Docker Compose

Fichiers `docker-compose.yml` des services hébergés sur **SRV-WEB-01** (`10.10.10.20`).

| Dossier | Service | Accès |
| --- | --- | --- |
| `portainer/` | Portainer — gestion visuelle de Docker | `https://10.10.10.20:9443` |
| `monitoring/` | Prometheus + Grafana + node-exporter | `http://10.10.10.20:3000` |
| `npm/` | Nginx Proxy Manager (reverse proxy) | `http://10.10.10.20:81` |

## 🔒 Secrets

Aucun secret n'est stocké dans les `docker-compose.yml` versionnés.
Les valeurs sensibles (mots de passe admin, clés) sont lues depuis un fichier `.env`
**non versionné** (ignoré par `.gitignore`). Un modèle **`.env.example`** liste les
variables attendues, sans valeur réelle.

Pour réutiliser une pile : copier `.env.example` en `.env` et renseigner les vraies
valeurs localement.

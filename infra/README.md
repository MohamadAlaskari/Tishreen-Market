# infra

Lokale Dev-Umgebung und später Deployment-Artefakte (docs/09 §4, docs/11).

## PostgreSQL 15 (dev)

```bash
cp .env.example .env    # optional: Ports/Credentials anpassen (.env bleibt uncommittet)
docker compose up -d postgres
```

Daten liegen im benannten Volume `tishreen-pgdata` und überleben Container-Neustarts.
Ohne `.env` gelten die Dev-Defaults aus `docker-compose.yml` (nur für lokale Entwicklung).

Später hier: `nginx.conf`, `scripts/backup.sh`, `scripts/restore.sh` (Phase 5).

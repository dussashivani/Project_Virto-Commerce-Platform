#!/usr/bin/env bash
# Roll back image versions: scripts/rollback.sh <previous .env.lock file>
# Data rollback is separate (restore.sh). Always take backup.sh BEFORE an upgrade.
source "$(dirname "$0")/_lib.sh"; need docker
LOCK="${1:?usage: rollback.sh <env.lock-file-of-previous-release>}"
[ -f "$LOCK" ] || { echo "no such file $LOCK" >&2; exit 2; }
set -a; . ./.env; . "$LOCK"; set +a
docker compose pull
docker compose up -d --wait --wait-timeout 600
"$(dirname "$0")/validate.sh"

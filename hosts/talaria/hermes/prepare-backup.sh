#!/usr/bin/env bash
set -euo pipefail
umask 077

: "${HERMES_BACKUP_MOUNT:?}"
: "${HERMES_BACKUP_STAGING:?}"
: "${HERMES_BACKUP_RESTART_MARKER:?}"

# Fail before stopping Hermes if the NAS or required sources are unavailable.
source=$(findmnt -rn -M "$HERMES_BACKUP_MOUNT" -t cifs -o SOURCE)
if [ "$source" != "//100.113.228.33/self-hosted-services" ]; then
    echo "Tanker SMB share is not mounted at $HERMES_BACKUP_MOUNT" >&2
    exit 1
fi
test -f /var/lib/hermes/data/config.yaml
test -r /etc/hermes/docker-compose.yml
test -r /etc/hermes/mcp-config.yaml
test -r /run/agenix/hermes-dashboard-env
test -r /run/agenix/hermes-homeassistant-env
install -d -m 700 "$HERMES_BACKUP_MOUNT/hermes-restic"
install -d -m 700 "$HERMES_BACKUP_STAGING/data" "$HERMES_BACKUP_STAGING/config" "$HERMES_BACKUP_STAGING/secrets"

resume_hermes() {
    if [ -e "$HERMES_BACKUP_RESTART_MARKER" ]; then
        systemctl start hermes-docker-compose.service
        rm -f -- "$HERMES_BACKUP_RESTART_MARKER"
    fi
}
trap resume_hermes EXIT

# Preserve an intentionally stopped gateway. Record the restart intent before
# stopping so ExecStopPost can also recover from interruption during the stop.
if systemctl is-active --quiet hermes-docker-compose.service; then
    touch "$HERMES_BACKUP_RESTART_MARKER"
    systemctl stop hermes-docker-compose.service
fi

# Copy all state, including hidden files, SQLite WALs, sessions and credentials.
# Keep the stage between runs so rsync only copies changed files next time.
rsync -a --delete -- /var/lib/hermes/data/ "$HERMES_BACKUP_STAGING/data/"
cp -L --preserve=mode,timestamps -- /etc/hermes/docker-compose.yml /etc/hermes/mcp-config.yaml "$HERMES_BACKUP_STAGING/config/"
cp -L --preserve=mode,timestamps -- /run/agenix/hermes-dashboard-env /run/agenix/hermes-homeassistant-env "$HERMES_BACKUP_STAGING/secrets/"
if [ -r /run/agenix/hermes-mealie-env ]; then
    cp -L --preserve=mode,timestamps -- /run/agenix/hermes-mealie-env "$HERMES_BACKUP_STAGING/secrets/"
else
    rm -f -- "$HERMES_BACKUP_STAGING/secrets/hermes-mealie-env"
fi

# Resume now; repository initialization, upload, pruning and checks run online.
resume_hermes

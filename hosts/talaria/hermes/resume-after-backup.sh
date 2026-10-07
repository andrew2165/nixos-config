#!/usr/bin/env bash
set -euo pipefail

: "${HERMES_BACKUP_RESTART_MARKER:?}"

if [ -e "$HERMES_BACKUP_RESTART_MARKER" ]; then
    systemctl start hermes-docker-compose.service
    rm -f -- "$HERMES_BACKUP_RESTART_MARKER"
fi

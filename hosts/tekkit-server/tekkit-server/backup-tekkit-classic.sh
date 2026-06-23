#!/usr/bin/env bash
set -euo pipefail

# Back up the Tekkit Classic Podman container image plus the persistent server
# volume. A container export alone would not include the world data.

CONTAINER="${CONTAINER:-tekkit-classic}"
IMAGE="${IMAGE:-localhost/tekkit-classic:local}"
IMAGE_FALLBACK="${IMAGE_FALLBACK:-tekkit-classic:local}"
VOLUME="${VOLUME:-tekkit_tekkit-server-data}"
SERVICE="${SERVICE:-podman-tekkit-classic.service}"
BACKUP_ROOT="${BACKUP_ROOT:-}"
STOP_SERVICE="${STOP_SERVICE:-1}"

STAMP="$(date +%Y%m%d-%H%M%S)"
NAME="tekkit-classic-backup-$STAMP"

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

default_backup_root() {
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ] && command -v getent >/dev/null 2>&1; then
    local passwd_entry home_dir
    passwd_entry="$(getent passwd "$SUDO_USER" || true)"
    if [ -n "$passwd_entry" ]; then
      IFS=: read -r _ _ _ _ _ home_dir _ <<< "$passwd_entry"
      printf '%s\n' "$home_dir"
      return
    fi
  fi

  printf '%s\n' "$HOME"
}

restore_service() {
  if [ "${WAS_ACTIVE:-0}" = 1 ]; then
    echo "Restarting $SERVICE"
    run_root systemctl start "$SERVICE" || true
  fi
}

require_cmd podman
require_cmd tar
require_cmd sha256sum

if [ -z "$BACKUP_ROOT" ]; then
  BACKUP_ROOT="$(default_backup_root)"
fi

WORK="$BACKUP_ROOT/$NAME"
ARCHIVE="$BACKUP_ROOT/$NAME.tar.gz"

mkdir -p "$WORK"

cat > "$WORK/backup-manifest.env" <<EOF
CONTAINER=$CONTAINER
IMAGE=$IMAGE
IMAGE_FALLBACK=$IMAGE_FALLBACK
VOLUME=$VOLUME
SERVICE=$SERVICE
STAMP=$STAMP
EOF

echo "Writing runtime metadata where available"
if ! run_root podman inspect "$CONTAINER" > "$WORK/container-inspect.json" 2> "$WORK/container-inspect.err"; then
  echo "Container $CONTAINER was not present; continuing without container metadata"
fi

if ! run_root podman volume inspect "$VOLUME" > "$WORK/volume-inspect.json"; then
  echo
  echo "Could not find required volume: $VOLUME" >&2
  echo "Available Podman volumes:" >&2
  run_root podman volume ls >&2
  exit 1
fi

WAS_ACTIVE=0
if [ "$STOP_SERVICE" = 1 ] && run_root systemctl is-active --quiet "$SERVICE"; then
  WAS_ACTIVE=1
  echo "Stopping $SERVICE for a consistent backup"
  run_root systemctl stop "$SERVICE"
fi
trap restore_service EXIT

if ! run_root podman image exists "$IMAGE"; then
  echo "Image $IMAGE not found; trying $IMAGE_FALLBACK"
  IMAGE="$IMAGE_FALLBACK"
fi

if ! run_root podman image exists "$IMAGE"; then
  echo
  echo "Could not find required image: $IMAGE" >&2
  echo "Available Podman images:" >&2
  run_root podman images >&2
  exit 1
fi

echo "Saving image $IMAGE"
run_root podman save -o "$WORK/tekkit-classic-image.tar" "$IMAGE"

echo "Archiving volume $VOLUME"
VOL_MOUNT="$(run_root podman volume inspect "$VOLUME" --format '{{ .Mountpoint }}')"
run_root tar -C "$VOL_MOUNT" -cpf "$WORK/tekkit-server-data.tar" .

if [ "$(id -u)" -ne 0 ]; then
  run_root chown -R "$(id -u):$(id -g)" "$WORK"
fi

echo "Creating $ARCHIVE"
tar -C "$BACKUP_ROOT" -czf "$ARCHIVE" "$NAME"
cd "$BACKUP_ROOT"
sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"

echo
echo "Backup complete:"
echo "  $ARCHIVE"
echo "  $ARCHIVE.sha256"

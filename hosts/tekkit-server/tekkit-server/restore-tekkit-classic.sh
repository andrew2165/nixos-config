#!/usr/bin/env bash
set -euo pipefail

# Restore a backup made by backup-tekkit-classic.sh. The backup contains both
# the Podman image and the persistent Tekkit server volume.

VOLUME="${VOLUME:-tekkit_tekkit-server-data}"
SERVICE="${SERVICE:-podman-tekkit-classic.service}"
STOP_SERVICE="${STOP_SERVICE:-1}"
FORCE="${FORCE:-0}"
KEEP_EXTRACT="${KEEP_EXTRACT:-0}"

usage() {
  cat >&2 <<EOF
Usage: sudo bash restore.sh [--force] /path/to/tekkit-classic-backup-YYYYMMDD-HHMMSS.tar.gz

Environment overrides:
  VOLUME=tekkit_tekkit-server-data
  SERVICE=podman-tekkit-classic.service
  STOP_SERVICE=1
  FORCE=0
  KEEP_EXTRACT=0
EOF
}

die() {
  echo "$*" >&2
  exit 1
}

run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Missing required command: $1"
  fi
}

ARCHIVE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -n "$ARCHIVE" ]; then
        usage
        die "Only one backup archive can be restored at a time."
      fi
      ARCHIVE="$1"
      shift
      ;;
  esac
done

if [ -z "$ARCHIVE" ]; then
  usage
  exit 1
fi

require_cmd podman
require_cmd tar
require_cmd find
require_cmd mktemp
require_cmd sha256sum

ARCHIVE_DIR="$(cd -- "$(dirname -- "$ARCHIVE")" && pwd)"
ARCHIVE_BASE="$(basename -- "$ARCHIVE")"
ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_BASE"
SHA_PATH="$ARCHIVE_PATH.sha256"

[ -f "$ARCHIVE_PATH" ] || die "Backup archive not found: $ARCHIVE_PATH"

TMP_PARENT="${TMPDIR:-/tmp}"
EXTRACT_DIR="$(mktemp -d "${TMP_PARENT%/}/tekkit-restore.XXXXXX")"
WAS_ACTIVE=0

cleanup() {
  status=$?

  if [ "$KEEP_EXTRACT" = 1 ]; then
    echo "Keeping extracted backup at $EXTRACT_DIR"
  else
    rm -rf "$EXTRACT_DIR"
  fi

  if [ "${WAS_ACTIVE:-0}" = 1 ]; then
    echo "Restarting $SERVICE"
    run_root systemctl start "$SERVICE" || true
  fi

  exit "$status"
}
trap cleanup EXIT

if [ -f "$SHA_PATH" ]; then
  echo "Verifying checksum $SHA_PATH"
  (cd "$ARCHIVE_DIR" && sha256sum -c "$ARCHIVE_BASE.sha256")
else
  echo "No checksum file found at $SHA_PATH; skipping checksum verification"
fi

echo "Extracting $ARCHIVE_PATH"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

IMAGE_TAR="$(find "$EXTRACT_DIR" -type f -name tekkit-classic-image.tar -print -quit)"
DATA_TAR="$(find "$EXTRACT_DIR" -type f -name tekkit-server-data.tar -print -quit)"

[ -n "$IMAGE_TAR" ] || die "Could not find tekkit-classic-image.tar inside backup."
[ -n "$DATA_TAR" ] || die "Could not find tekkit-server-data.tar inside backup."

echo "Loading Podman image from backup"
run_root podman load -i "$IMAGE_TAR"

if [ "$STOP_SERVICE" = 1 ] && run_root systemctl is-active --quiet "$SERVICE"; then
  WAS_ACTIVE=1
  echo "Stopping $SERVICE before replacing volume data"
  run_root systemctl stop "$SERVICE"
fi

if run_root podman volume inspect "$VOLUME" >/dev/null 2>&1; then
  echo
  echo "Volume $VOLUME already exists and its contents will be replaced."
  if [ "$FORCE" != 1 ]; then
    printf 'Type RESTORE to continue: '
    read -r answer
    [ "$answer" = "RESTORE" ] || die "Restore cancelled."
  fi
else
  echo "Creating volume $VOLUME"
  run_root podman volume create "$VOLUME" >/dev/null
fi

VOL_MOUNT="$(run_root podman volume inspect "$VOLUME" --format '{{ .Mountpoint }}')"
[ -n "$VOL_MOUNT" ] || die "Could not determine mountpoint for volume $VOLUME"
[ "$VOL_MOUNT" != "/" ] || die "Refusing to restore into /"

echo "Clearing current contents of $VOLUME"
run_root find "$VOL_MOUNT" -mindepth 1 -exec rm -rf -- {} +

echo "Restoring server data into $VOLUME"
run_root tar -C "$VOL_MOUNT" -xpf "$DATA_TAR"

echo
echo "Restore complete."
echo "Volume restored: $VOLUME"
if [ "$WAS_ACTIVE" != 1 ]; then
  echo "Service was not running; start it with: sudo systemctl start $SERVICE"
fi

#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="${1:-.env.rclone}"
set -a; source "$ENV_FILE"; set +a
mkdir -p "$RCLONE_UNION_MOUNT" "$RCLONE_CACHE_DIR" "$RCLONE_LOG_DIR"
rclone mount "${RCLONE_UNION_NAME}:" "$RCLONE_UNION_MOUNT" \
  --config "$RCLONE_CONFIG_PATH" \
  --allow-other \
  --dir-cache-time 1000h \
  --poll-interval 1m \
  --vfs-cache-mode full \
  --vfs-cache-max-age 24h \
  --vfs-cache-max-size 20G \
  --cache-dir "$RCLONE_CACHE_DIR" \
  --log-file "$RCLONE_LOG_DIR/rclone-union.log" \
  --log-level INFO

#!/usr/bin/env bash
set -euo pipefail
ENV_FILE="${1:-.env.rclone}"
set -a; source "$ENV_FILE"; set +a
mkdir -p "$(dirname "$RCLONE_CONFIG_PATH")" "$RCLONE_CACHE_DIR" "$RCLONE_LOG_DIR" "$RCLONE_UNION_MOUNT"
cat > "$RCLONE_CONFIG_PATH" <<CFG
[${RCLONE_GDRIVE1_NAME}]
type = drive
token = {"access_token":"${RCLONE_GDRIVE1_ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${RCLONE_GDRIVE1_REFRESH_TOKEN}","expiry":"${RCLONE_GDRIVE1_EXPIRY}"}
client_id = ${RCLONE_CLIENT_ID}
client_secret = ${RCLONE_CLIENT_SECRET}
scope = drive

[${RCLONE_GDRIVE2_NAME}]
type = drive
token = {"access_token":"${RCLONE_GDRIVE2_ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${RCLONE_GDRIVE2_REFRESH_TOKEN}","expiry":"${RCLONE_GDRIVE2_EXPIRY}"}
client_id = ${RCLONE_CLIENT_ID}
client_secret = ${RCLONE_CLIENT_SECRET}
scope = drive

[${RCLONE_GDRIVE3_NAME}]
type = drive
token = {"access_token":"${RCLONE_GDRIVE3_ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${RCLONE_GDRIVE3_REFRESH_TOKEN}","expiry":"${RCLONE_GDRIVE3_EXPIRY}"}
client_id = ${RCLONE_CLIENT_ID}
client_secret = ${RCLONE_CLIENT_SECRET}
scope = drive

[${RCLONE_GDRIVE4_NAME}]
type = drive
token = {"access_token":"${RCLONE_GDRIVE4_ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${RCLONE_GDRIVE4_REFRESH_TOKEN}","expiry":"${RCLONE_GDRIVE4_EXPIRY}"}
client_id = ${RCLONE_CLIENT_ID}
client_secret = ${RCLONE_CLIENT_SECRET}
scope = drive

[${RCLONE_GDRIVE5_NAME}]
type = drive
token = {"access_token":"${RCLONE_GDRIVE5_ACCESS_TOKEN}","token_type":"Bearer","refresh_token":"${RCLONE_GDRIVE5_REFRESH_TOKEN}","expiry":"${RCLONE_GDRIVE5_EXPIRY}"}
client_id = ${RCLONE_CLIENT_ID}
client_secret = ${RCLONE_CLIENT_SECRET}
scope = drive

[${RCLONE_UNION_NAME}]
type = union
upstreams = ${RCLONE_UNION_UPSTREAMS}
create_policy = ${RCLONE_UNION_CREATE_POLICY}
search_policy = ${RCLONE_UNION_SEARCH_POLICY}
CFG
chmod 600 "$RCLONE_CONFIG_PATH"
echo "wrote $RCLONE_CONFIG_PATH"

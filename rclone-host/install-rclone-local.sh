#!/usr/bin/env bash
set -euo pipefail
PREFIX="${PREFIX:-$HOME/.local/bin}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
mkdir -p "$PREFIX"
curl -fL --retry 3 --retry-delay 3 -o "$TMPDIR/rclone.zip" https://downloads.rclone.org/rclone-current-linux-amd64.zip
python3 - <<'PY' "$TMPDIR/rclone.zip" "$TMPDIR/out"
import sys, zipfile, pathlib
zip_path = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
with zipfile.ZipFile(zip_path) as z:
    name = [n for n in z.namelist() if n.endswith('/rclone')][0]
    z.extract(name, out)
print(out / name)
PY
BIN_PATH="$(find "$TMPDIR/out" -type f -name rclone | head -n1)"
install -m 0755 "$BIN_PATH" "$PREFIX/rclone"
"$PREFIX/rclone" version | head -n 5

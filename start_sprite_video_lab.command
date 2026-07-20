#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST="${SPRITE_VIDEO_LAB_HOST:-127.0.0.1}"
PORT="${SPRITE_VIDEO_LAB_PORT:-8894}"
URL="http://${HOST}:${PORT}/"
LOG_FILE="${SPRITE_VIDEO_LAB_LOG:-/tmp/sprite-video-lab-${PORT}.log}"
PYTHON="${SPRITE_VIDEO_LAB_PYTHON:-${ROOT_DIR}/.venv/bin/python}"

cd "$ROOT_DIR"

echo "Sprite Video Lab"
echo "Project: $ROOT_DIR"
echo "URL:     $URL"
echo "Log:     $LOG_FILE"
echo

if ! command -v lsof >/dev/null 2>&1; then
  echo "Error: lsof is required to check whether port ${PORT} is already in use."
  exit 1
fi

existing_pid="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN | head -n 1 || true)"
if [[ -n "$existing_pid" ]]; then
  echo "Already running on port ${PORT}, PID: ${existing_pid}"
  command -v open >/dev/null 2>&1 && open "$URL" || true
  echo "Done."
  exit 0
fi

if [[ ! -x "$PYTHON" ]]; then
  echo "Local Python runtime not found. Creating .venv..."
  python3 -m venv .venv
  PYTHON="${ROOT_DIR}/.venv/bin/python"
  "$PYTHON" -m pip install --upgrade pip
  "$PYTHON" -m pip install -r requirements.txt
fi

if ! "$PYTHON" - <<'PY' >/dev/null 2>&1
import PIL
PY
then
  echo "Installing Python dependencies..."
  "$PYTHON" -m pip install -r requirements.txt
fi

echo "Starting server..."
export SPRITE_LAUNCH_ROOT="$ROOT_DIR"
export SPRITE_LAUNCH_HOST="$HOST"
export SPRITE_LAUNCH_PORT="$PORT"
export SPRITE_LAUNCH_LOG="$LOG_FILE"
export SPRITE_LAUNCH_PYTHON="$PYTHON"
server_pid="$("$PYTHON" - <<'PY'
import os
import subprocess

root = os.environ["SPRITE_LAUNCH_ROOT"]
host = os.environ["SPRITE_LAUNCH_HOST"]
port = os.environ["SPRITE_LAUNCH_PORT"]
log_path = os.environ["SPRITE_LAUNCH_LOG"]
python = os.environ["SPRITE_LAUNCH_PYTHON"]

log = open(log_path, "ab", buffering=0)
env = os.environ.copy()
env["SPRITE_VIDEO_LAB_HOST"] = host
env["SPRITE_VIDEO_LAB_PORT"] = port

proc = subprocess.Popen(
    [python, "server.py", "--serve", "--host", host, "--port", port],
    cwd=root,
    env=env,
    stdin=subprocess.DEVNULL,
    stdout=log,
    stderr=subprocess.STDOUT,
    close_fds=True,
    start_new_session=True,
)
print(proc.pid)
PY
)"

for _ in {1..20}; do
  if lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 0.25
done

if lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Started, PID: ${server_pid}"
  command -v open >/dev/null 2>&1 && open "$URL" || true
  echo "Done."
else
  echo "Failed to start. Recent log output:"
  tail -n 40 "$LOG_FILE" || true
  exit 1
fi

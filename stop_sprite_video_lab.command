#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${SPRITE_VIDEO_LAB_PORT:-8894}"
LOG_FILE="${SPRITE_VIDEO_LAB_LOG:-/tmp/sprite-video-lab-${PORT}.log}"

cd "$ROOT_DIR"

echo "Sprite Video Lab"
echo "Project: $ROOT_DIR"
echo "Port:    $PORT"
echo

if ! command -v lsof >/dev/null 2>&1; then
  echo "Error: lsof is required to find the running server."
  exit 1
fi

pids="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN || true)"

if [[ -z "$pids" ]]; then
  echo "No server is listening on port ${PORT}."
  exit 0
fi

echo "Stopping PID(s):"
echo "$pids"
echo

while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  kill "$pid" 2>/dev/null || true
done <<< "$pids"

sleep 1

remaining="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN || true)"
if [[ -n "$remaining" ]]; then
  echo "Some process is still listening on port ${PORT}; forcing stop:"
  echo "$remaining"
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill -9 "$pid" 2>/dev/null || true
  done <<< "$remaining"
fi

echo "Stopped."
echo "Log file remains at: $LOG_FILE"


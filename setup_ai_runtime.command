#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
AI_ROOT="${SPRITE_VIDEO_LAB_AI_ROOT:-${ROOT_DIR}/work/models}"
VENV_DIR="${SPRITE_VIDEO_LAB_VENV:-${ROOT_DIR}/.venv}"
PYTHON="${SPRITE_VIDEO_LAB_PYTHON:-${VENV_DIR}/bin/python}"
CORRIDORKEY_ROOT="${SPRITE_VIDEO_LAB_CORRIDORKEY_ROOT:-${AI_ROOT}/CorridorKey}"

cd "$ROOT_DIR"

echo "Sprite Video Lab AI runtime setup"
echo "Project:       $ROOT_DIR"
echo "Python venv:   $VENV_DIR"
echo "Model cache:   ${SPRITE_VIDEO_LAB_AI_MODEL_CACHE:-${AI_ROOT}/huggingface}"
echo "CorridorKey:   $CORRIDORKEY_ROOT"
echo

if [[ ! -x "$PYTHON" ]]; then
  echo "Creating Python runtime..."
  python3 -m venv "$VENV_DIR"
  PYTHON="${VENV_DIR}/bin/python"
fi

"$PYTHON" -m pip install --upgrade pip
"$PYTHON" -m pip install -r requirements.txt
"$PYTHON" -m pip install -r requirements-ai.txt

if [[ ! -d "${CORRIDORKEY_ROOT}/CorridorKeyModule" ]]; then
  if command -v git >/dev/null 2>&1; then
    mkdir -p "$(dirname "$CORRIDORKEY_ROOT")"
    echo "Cloning CorridorKey..."
    git clone --depth 1 https://github.com/nikopueringer/CorridorKey "$CORRIDORKEY_ROOT"
  else
    echo "CorridorKey was not cloned because git was not found."
    echo "Install git or clone https://github.com/nikopueringer/CorridorKey to:"
    echo "  $CORRIDORKEY_ROOT"
  fi
else
  echo "CorridorKey is available at $CORRIDORKEY_ROOT"
fi

echo
echo "AI runtime is ready."
echo "Start the app with ./start_sprite_video_lab.command"

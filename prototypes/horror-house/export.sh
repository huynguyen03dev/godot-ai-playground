#!/usr/bin/env bash
# Blackout — export pipeline.
# Exports Linux + Windows x86_64 release builds, strips the dev-only MCPRuntime
# autoload so the shipped binary starts clean (no missing-script errors), then
# restores the dev project.godot so editor MCP testing keeps working.
#
# Usage:  bash prototypes/horror-house/export.sh
set -euo pipefail

ROOT="/home/hazeruno/IT/workspace/godot"
GODOT="/home/hazeruno/.local/bin/godot"
cd "$ROOT"

echo "==> Pre-flight: verify project loads clean"
timeout 90 xvfb-run -a --server-args="-screen 0 1280x720x24" \
    "$GODOT" --editor --path . --quit 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|Failed to load|Failed to instantiate" \
    | grep -ivE "alsa|audio_driver|audio_server|icon" || true

echo "==> Backing up project.godot (dev autoloads)"
cp project.godot project.godot.devbak

echo "==> Stripping MCPRuntime dev autoload for clean release build"
# Remove the MCPRuntime line; keep AudioManager (needed in-game).
python3 - <<'PY'
import re
p = "project.godot"
s = open(p).read()
s = s.replace('MCPRuntime="*res://addons/godot_mcp/runtime/mcp_runtime.gd"\n', '')
open(p, "w").write(s)
print("  MCPRuntime autoload removed.")
PY

mkdir -p build build/Blackout-Linux-x86_64 build/Blackout-Windows-x86_64

echo "==> Exporting Linux x86_64 (preset 0: Blackout-Linux)"
timeout 300 xvfb-run -a --server-args="-screen 0 1280x720x24" \
    "$GODOT" --headless --path . --export-release "Blackout-Linux" "build/Blackout-Linux-x86_64/Blackout.x86_64" 2>&1 \
    | grep -iE "error|export|Saving|success" | grep -ivE "alsa|audio_driver|audio_server" | tail -15 || true

echo "==> Exporting Windows x86_64 (preset 1: Blackout-Windows)"
timeout 300 xvfb-run -a --server-args="-screen 0 1280x720x24" \
    "$GODOT" --headless --path . --export-release "Blackout-Windows" "build/Blackout-Windows-x86_64/Blackout.exe" 2>&1 \
    | grep -iE "error|export|Saving|success" | grep -ivE "alsa|audio_driver|audio_server" | tail -15 || true

echo "==> Restoring dev project.godot"
mv project.godot.devbak project.godot

echo "==> Build artifacts:"
ls -lh build/Blackout-Linux-x86_64/ build/Blackout-Windows-x86_64/ 2>&1

echo "==> Done."

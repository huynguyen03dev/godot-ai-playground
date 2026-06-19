#!/bin/bash
# Start Godot editor with the MCP plugin enabled
# Run this before using the MCP server with your AI agent
# The MCP server will start automatically when the AI agent connects

GODOT_BIN="/home/hazeruno/.local/bin/godot"
PROJECT_DIR="/home/hazeruno/IT/workspace/godot"

echo "Starting Godot editor with MCP plugin..."
echo "Project: $PROJECT_DIR"
echo ""
echo "Note: The MCP server is started by the AI agent."
echo "This script only starts Godot so the plugin can connect."
echo ""

# Use virtual framebuffer for headless server environments
# Increase display depth and resolution for better compatibility
xvfb-run -a --server-args="-screen 0 1280x720x24" \
    "$GODOT_BIN" --editor --path "$PROJECT_DIR" "$@"

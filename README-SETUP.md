# Godot MCP Setup for Amp (tomyud1/godot-mcp)

Local MCP server + Godot plugin for AI agent prototyping.

## Files

| File | Purpose |
|------|---------|
| `.mcp.json` | Amp project-level MCP config (points to local server) |
| `project.godot` | Base Godot project with MCP plugin enabled |
| `addons/godot_mcp/` | Godot MCP plugin (from tomyud1 repo) |
| `godot-mcp/` | Cloned repo + built MCP server |
| `start-godot-mcp.sh` | Helper to start Godot editor with virtual display |

## Quick Start

### 1. Start Godot Editor

```bash
./start-godot-mcp.sh
```

This runs Godot with `xvfb-run` (virtual framebuffer) so it works on headless servers.

If you are starting it from an Amp tool call (or any non-interactive shell), run it in a detached `screen` session so the tool call doesn't block:

```bash
screen -dmS godot-editor ./start-godot-mcp.sh
```

You can re-attach later with `screen -r godot-editor` or view the log at `/tmp/godot-mcp.log`.

Wait for the editor to fully load. The plugin will show:
- `MCP: Connecting...` → `MCP: No Agent` (orange = waiting for agent)
- `MCP: Agent Active` (green = agent connected)

### 2. Use with Amp

The `.mcp.json` in this folder is automatically picked up by Amp.

When you ask Amp to work on your Godot project, the MCP tools become available:
- Scene/node creation and editing
- Script reading/writing
- Project settings access
- Runtime observation (when game is running)
- Console error reading

### 3. Create Prototype Projects

Create new projects as subfolders of this workspace, then symlink the addon:

```bash
mkdir -p prototype-01/addons
ln -s ../../addons/godot_mcp prototype-01/addons/godot_mcp
# Then edit prototype-01/project.godot to enable the plugin
```

Or just work in the root project directly.

## How It Works

```
Amp Agent ←(stdio/MCP)→ MCP Server ←(WebSocket:6505)→ Godot Editor Plugin
```

1. Amp connects to `node godot-mcp/mcp-server/dist/index.js` via MCP stdio
2. MCP server starts WebSocket on port 6505
3. Godot editor (with plugin) connects to ws://127.0.0.1:6505
4. Agent sends tool calls → MCP server → Godot plugin → tool executes
5. Results flow back: Godot → MCP server → Amp

## Available Tools (42 across 6 categories)

See the tomyud1 repo for full list. Key ones:
- File operations (browse, read, search, create scripts)
- Scene editing (list, read, create, modify)
- Node manipulation (add, remove, set properties)
- Script operations (read, edit, validate)
- Project settings
- Editor commands (play, stop, screenshot)
- Runtime tools (observe running game)

## Troubleshooting

**MCP: Disconnected (red)** → Godot plugin can't reach the server. Make sure:
- MCP server is running (started by Amp when you use it)
- Port 6505 is free (`lsof -i :6505`)

**Godot not starting** → Make sure `xvfb-run` is available: `which xvfb-run`

**Plugin not showing** → Check `Project → Project Settings → Plugins` → "Godot MCP" is enabled.

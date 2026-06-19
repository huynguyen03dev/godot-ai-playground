---
name: godot-mcp-headless
description: Drive the Godot editor through the godot MCP server in this headless (xvfb) environment — launch/connect, build & edit scenes, run the game, screenshot, inject input, and read errors. Use whenever a task involves building, editing, running, or visually verifying a Godot scene here. Covers the non-obvious gotchas (MCPRuntime autoload, runtime_connected false-negatives, renderer/project.godot restarts).
---

# Godot via MCP (headless)

## Overview

Godot runs **headless under xvfb** on this machine and exposes an editor-control API through the **godot MCP server on port 6505**. You can create/edit scenes and scripts, run the game, take screenshots, inject input, and read errors — all without a visible window. This is the Godot analog of browser-testing-with-devtools: it gives you eyes and hands inside the running game so you verify behavior instead of guessing.

## When to use

Any task that touches a Godot scene/script here: building a level, wiring nodes, writing GDScript, tuning lighting/shaders, or confirming a change actually works at runtime.

## Step 0 — Is Godot connected?

Always start with `get_godot_status`. If `connected: false`, Godot isn't running (or its plugin dropped). Launch it:

```bash
xvfb-run -a --server-args="-screen 0 1280x720x24" \
  /home/hazeruno/.local/bin/godot --editor --path /home/hazeruno/IT/workspace/godot
```

Run it as a **background Bash** (`run_in_background: true`) — launching directly is more reliable than the `start-godot-mcp.sh` + `screen` wrapper, whose detached session sometimes dies immediately. Boot + asset import takes **~30–60s**; poll `get_godot_status` until `connected: true`. (`start-godot-mcp.sh` documents the same command if you need a reference.)

## The testing loop

The canonical cycle (mirrors the MCP server's own `testing-loop` guide):

1. `run_scene({ scene: "res://...", wait_for_runtime: true })`
2. `take_screenshot` / `send_input` / `query_runtime_node`
3. `get_errors` (and `get_console_log` for the running game's stdout)
4. `stop_scene` **before editing any script** — otherwise errors repeat every frame.

### Gotcha: `runtime_connected: false` is often a false negative
The in-game `MCPRuntime` helper connects a few seconds **after** `run_scene` returns, so the response frequently says `runtime_connected: false` even when it's about to work. Don't trust it — `wait` ~2–3s then re-check with `get_runtime_status` (`runtime_helper_connected: true`). Screenshots/input need that helper live.

### Gotcha: screenshots/input require the `MCPRuntime` autoload
If the helper never connects, the autoload probably isn't registered. Check `setup_autoload({operation:"list"})`; if missing, `setup_autoload({operation:"add", name:"MCPRuntime", path:"res://addons/godot_mcp/runtime/mcp_runtime.gd"})`. **Then restart Godot** — a running editor won't pick up a newly-added autoload for the games it launches.

## Editing project.godot / renderer / autoloads → restart required

Anything written to `project.godot` while the editor is running (renderer method, autoloads, main scene) is **not picked up until Godot restarts**. The ideal time to change the renderer is *while the editor is closed*. Note Godot omits settings equal to their default — e.g. `renderer/rendering_method="forward_plus"` won't appear in the file because Forward+ is the default; confirm the active renderer from the running game's console log (`Vulkan ... - Forward+`).

**Forward+ vs Mobile matters for visuals:** volumetric fog, SSAO, SSIL, SSR, and glow only render on **forward_plus**. If atmospheric effects look absent, check the renderer first.

## Importing external assets (e.g. Kenney CC0)

1. Download/extract on disk, copy files into `res://assets/...` via Bash.
2. `rescan_filesystem` so Godot imports them and assigns `uid://`s.
3. GLBs import **without collision** by default — add explicit collision (primitive `CollisionShape3D` floor/walls, or a StaticBody) or the player falls through the world.

## Editing scenes/scripts

- Small/surgical scene tweaks: prefer the MCP tools (`add_node`, `modify_node_property`, `set_*`).
- Bulk/precise `.tscn` or `.gd` work: editing the file directly with Edit/Write is fine — declare `[sub_resource]` blocks before nodes and reference them with `SubResource("id")`. Run `validate_script` / `get_errors` after.
- `CollisionShape3D` nodes are useless without a `shape` resource assigned — easy thing to forget and it makes physics silently fail.

## Benign headless errors (ignore)

- ALSA / "All audio drivers failed, falling back to the dummy driver" — no audio hardware in the container.
- Missing `res://icon.svg` — cosmetic.

These show up in `get_errors` every run and are **not** real failures.

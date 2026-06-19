# Godot AI Prototyping Playground

A **Godot 4.6** workspace for rapidly building and verifying game prototypes — designed to be driven by an AI agent through the [godot-mcp](https://github.com/) editor-control server (create scenes, write scripts, run the game, screenshot, inject input, read errors — all headlessly).

Each prototype is self-contained under [`prototypes/`](prototypes/). Assets are shared at the repo root so any prototype can reuse them.

## Layout

```
prototypes/            One folder per prototype (scene + its scripts)
  horror-house/        First-person 3D horror demo
assets/                Shared, reusable assets
  kenney/              Kenney CC0 3D packs (dungeon, furniture, buildings)
addons/
  godot_mcp/           MCP editor-control plugin
.claude/skills/        Agent playbooks (e.g. driving Godot via MCP headless)
project.godot          run/main_scene points at the active prototype
```

## Prototypes

| Prototype | Description | Main scene |
|-----------|-------------|------------|
| [`horror-house`](prototypes/horror-house/) | First-person 3D horror: flashlight, monster AI, volumetric fog, screen-space horror shader | `prototypes/horror-house/horror_house.tscn` |

## Running a prototype

1. Open the project in Godot 4.6+.
2. Either press **Play** (runs `run/main_scene` in `project.godot`), or open a prototype's scene and press **Play Scene** (`F6`).

> The project uses the **Forward+** renderer — advanced effects (volumetric fog, SSAO, glow) depend on it.

## Adding a new prototype

1. `mkdir prototypes/<name>` and put its scene + scripts there.
2. Reference shared assets via `res://assets/...`.
3. Optionally point `run/main_scene` in `project.godot` at it to make it the default Play target.
4. Add a row to the table above.

Keep each prototype's scripts inside its own folder (use `res://prototypes/<name>/...` paths) so prototypes stay independent.

## Working with the MCP agent

The headless launch + testing-loop workflow (and its gotchas) is documented as an agent skill in [`.claude/skills/godot-mcp-headless/`](.claude/skills/godot-mcp-headless/SKILL.md). See [`README-SETUP.md`](README-SETUP.md) for MCP server setup.

## Credits & License

- 3D assets by [Kenney](https://kenney.nl) — [CC0](https://creativecommons.org/publicdomain/zero/1.0/).
- Project code: MIT — see [LICENSE](LICENSE).
